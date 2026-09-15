<?php

error_reporting(E_ALL & ~E_DEPRECATED & ~E_USER_DEPRECATED);

require_once __DIR__ . '/../vendor/autoload.php';

use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;

use Condense\Database;
use Avogadrio\CactusSmilesConverter;
use Avogadrio\WikipediaSmilesConverter;
use Avogadrio\MoleculeRenderer;

$app = new Silex\Application();

// Uncomment the line below while debugging your app.
$app['debug'] = true;

// Load config.
$config = Spyc::YAMLLoad(getenv('AVOGADRIO_CONFIG'));

// Services.
$cacheDirectory = $config['cache_dir'];
if (!is_dir($cacheDirectory)) {
    @mkdir($cacheDirectory, 0770, true);
}

$wikiSmilesConverter = new WikipediaSmilesConverter(new Database('names_wiki', $cacheDirectory));
$smilesConverter = new CactusSmilesConverter(new Database('names', $cacheDirectory), $wikiSmilesConverter);
$moleculeRenderer = new MoleculeRenderer($config['sourire_service']);

$moleculeRenderer->setRenderChiralLabels(false); // Disable chiral labels.

/*
 * Route actions.
 */

/**
 * Action for frontend route.
 */
$app->get('/', function () use ($config) {
    return file_get_contents(__DIR__.'/index.html');
});

/**
 * Action for SMILES wallpaper route.
 */
$app->get('/api/smiles/{width}/{height}/{background}/{foreground}/{smiles}',
    function (Request $request, $width, $height, $background, $foreground, $smiles) use ($moleculeRenderer) {

        // Add label.
        $moleculeRenderer->setCustomLabel($request->get('label'));

        // Add rotation.
        $moleculeRenderer->setRotation((float) $request->get('rotation'));

        // Render molecule with background.
        $image = $moleculeRenderer->renderMoleculeWithBackground($smiles, $foreground, $background, $width, $height);

        // Return image to client.
        return new Response($image->response('png'), 200, ['Content-Type' => 'image/png']);
});

/**
 * Action for molecule-only SMILES route.
 */
$app->get('/api/smiles/{width}/{height}/{color}/{smiles}',
    function (Request $request, $width, $height, $color, $smiles) use ($moleculeRenderer) {

        // Add label.
        $moleculeRenderer->setCustomLabel($request->get('label'));

        // Add rotation.
        $moleculeRenderer->setRotation((float) $request->get('rotation'));

        // Render molecule only.
        $image = $moleculeRenderer->renderScaledMolecule($smiles, $color, $width, $height);

        // Return image to client.
        return new Response($image->response('png'), 200, ['Content-Type' => 'image/png']);
});

/**
 * Action for compound name wallpaper route.
 */
$app->get('/api/name/{width}/{height}/{background}/{foreground}/{name}',
    function (Request $request, $width, $height, $background, $foreground, $name) use ($app, $moleculeRenderer, $smilesConverter) {

        // Convert chemical name to SMILES if we can.
        $smiles = $smilesConverter->nameToSmiles($name);

        // Forward to SMILES route.
        if ($smiles !== null) {

            // Add label.
            $moleculeRenderer->setCustomLabel($request->get('label'));

            // Add rotation.
            $moleculeRenderer->setRotation((float) $request->get('rotation'));

            // Render molecule with background.
            $image = $moleculeRenderer->renderMoleculeWithBackground($smiles, $foreground, $background, $width, $height);

            // Return image to client.
            return new Response($image->response('png'), 200, ['Content-Type' => 'image/png']);
        }

        // Invalid chemical name.
        return $app->abort(404, "Chemical name could not be converted to SMILES.");
});

/**
 * Action for molecule-only compound name route.
 */
$app->get('/api/name/{width}/{height}/{color}/{name}',
    function (Request $request, $width, $height, $color, $name) use ($app, $moleculeRenderer, $smilesConverter) {

        // Convert chemical name to SMILES if we can.
        $smiles = $smilesConverter->nameToSmiles($name);

        // Forward  to SMILES route.
        if ($smiles !== null) {

            // Add label.
            $moleculeRenderer->setCustomLabel($request->get('label'));

            // Add rotation.
            $moleculeRenderer->setRotation((float) $request->get('rotation'));

            // Render molecule only.
            $image = $moleculeRenderer->renderScaledMolecule($smiles, $color, $width, $height);

            // Return image to client.
            return new Response($image->response('png'), 200, ['Content-Type' => 'image/png']);
        }

        // Invalid chemical name.
        return $app->abort(404, "Chemical name could not be converted to SMILES.");
});

/**
 * Action for checking if compound name exists.
 */
$app->get('/api/name/exists/{name}',
    function ($name) use ($config, $smilesConverter) {

        // Return JSON response (just a lone boolean).
        return new JsonResponse($smilesConverter->nameToSmiles($name) === null ? false : true);
});

$app->run();
