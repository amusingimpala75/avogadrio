<?php

error_reporting(E_ALL & ~E_DEPRECATED & ~E_USER_DEPRECATED);

require_once __DIR__ . '/../vendor/autoload.php';

use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;

use Intervention\Image\Format;

use Avogadrio\MoleculeRenderer;

$app = new Silex\Application();

// Uncomment the line below while debugging your app.
$app['debug'] = true;

// Load config.
$config = Spyc::YAMLLoad(getenv('AVOGADRIO_CONFIG'));

// Services.
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
$app->get('/api/smiles/wallpaper/{width}/{height}/{background}/{foreground}/{smiles}',
    function (Request $request, $width, $height, $background, $foreground, $smiles) use ($moleculeRenderer) {

        // Add label.
        $moleculeRenderer->setCustomLabel($request->get('label'));

        // Add rotation.
        $moleculeRenderer->setRotation((float) $request->get('rotation'));

        // Render molecule with background.
        $image = $moleculeRenderer->renderMoleculeWithBackground($smiles, $foreground, $background, $width, $height);

        // Return image to client.
        return new Response((string) $image->encodeUsingFormat(Format::PNG), 200, ['Content-Type' => 'image/png']);
});

/**
 * Action for molecule-only SMILES route.
 */
$app->get('/api/smiles/molecule/{width}/{height}/{background}/{foreground}/{smiles}',
    function (Request $request, $width, $height, $background, $foreground, $smiles) use ($moleculeRenderer) {

        // Add label.
        $moleculeRenderer->setCustomLabel($request->get('label'));

        // Add rotation.
        $moleculeRenderer->setRotation((float) $request->get('rotation'));

        // Render molecule only.
        $image = $moleculeRenderer->renderScaledMolecule($smiles, $foreground, $background, $width, $height);

        // Return image to client.
        return new Response((string) $image->encodeUsingFormat(Format::PNG), 200, ['Content-Type' => 'image/png']);
});

$app->run();
