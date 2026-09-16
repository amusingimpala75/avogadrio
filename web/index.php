<?php

error_reporting(E_ALL & ~E_DEPRECATED & ~E_USER_DEPRECATED);

$dir = $_SERVER['DOCUMENT_ROOT'];

require_once $dir . '/../vendor/autoload.php';

$app = new Silex\Application();

// Uncomment the line below while debugging your app.
$app['debug'] = true;

/*
 * Route actions.
 */

/**
 * Action for frontend route.
 */
$app->get('/', function () use ($dir) {
    return file_get_contents($dir .'/index.html');
});

$app->run();
