<?php

use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return response()->json([
        'app' => 'AdoptMatch RESTful API',
        'status' => 'online',
        'version' => '1.0.0',
        'health' => 'operational'
    ]);
});

