<?php

use Illuminate\Support\Facades\Route;

Route::withoutMiddleware([
    \Illuminate\Cookie\Middleware\EncryptCookies::class,
    \Illuminate\Cookie\Middleware\AddQueuedCookiesToResponse::class,
    \Illuminate\Session\Middleware\StartSession::class,
    \Illuminate\View\Middleware\ShareErrorsFromSession::class,
    \Illuminate\Foundation\Http\Middleware\ValidateCsrfToken::class,
])->get('/', function () {
    return response()->json([
        'app' => 'AdoptMatch RESTful API',
        'status' => 'online',
        'version' => '1.0.0',
        'health' => 'operational',
        'documentation' => [
            'health_check' => '/up',
            'pets' => '/api/v1/pets',
            'auth' => '/api/v1/auth',
        ],
    ]);
});
