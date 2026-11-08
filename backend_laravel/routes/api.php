<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\PhoneAuthController;
use App\Http\Controllers\Api\PetController;
use App\Http\Controllers\Api\AdoptionRequestController;
use App\Http\Controllers\Api\MessageController;
use App\Http\Controllers\Api\UploadController;

/*
|--------------------------------------------------------------------------
| AdoptMatch RESTful API Routes (v1)
|--------------------------------------------------------------------------
*/

Route::prefix('v1')->group(function () {

    // =====================================
    // 1. PUBLIC AUTHENTICATION & DISCOVERY
    // =====================================
    Route::prefix('auth')->group(function () {
        Route::post('/google', [AuthController::class, 'googleLogin']);
        Route::post('/login', [AuthController::class, 'emailLogin']);
        Route::post('/register', [AuthController::class, 'register']);
        Route::post('/phone/request', [PhoneAuthController::class, 'requestOtp'])->middleware('throttle:5,1');
        Route::post('/phone/verify', [PhoneAuthController::class, 'verifyOtp'])->middleware('throttle:10,1');
    });

    // Public Pet Catalog & Details
    Route::get('/pets', [PetController::class, 'index']);
    Route::get('/pets/{id}', [PetController::class, 'show'])->whereNumber('id');

    // =====================================
    // 2. PROTECTED ROUTES (SANCTUM BEARER)
    // =====================================
    Route::middleware('auth:sanctum')->group(function () {

        // User & Session & FCM Token Registration
        Route::get('/me', [AuthController::class, 'me']);
        Route::get('/auth/me', [AuthController::class, 'me']);
        Route::post('/auth/logout', [AuthController::class, 'logout']);
        Route::post('/auth/password', [AuthController::class, 'changePassword'])->middleware('throttle:10,1');
        Route::post('/auth/fcm-token', [AuthController::class, 'updateFcmToken']);

        // Media uploads require the same Sanctum identity as every other write.
        Route::post('/upload/image', [UploadController::class, 'uploadImage'])->middleware('throttle:20,1');

        // Literal routes MUST precede /pets/{id}, otherwise "nearby" is treated as an id.
        Route::get('/pets/swipe-stack', [PetController::class, 'getSwipeStack']);
        Route::get('/pets/nearby', [PetController::class, 'getNearbyPets']);
        Route::get('/favorites', [PetController::class, 'getFavorites']);
        Route::get('/pets/{id}/favorite', [PetController::class, 'getFavorite'])->whereNumber('id');
        Route::put('/pets/{id}/favorite', [PetController::class, 'addFavorite'])->whereNumber('id');
        Route::delete('/pets/{id}/favorite', [PetController::class, 'removeFavorite'])->whereNumber('id');
        Route::post('/pets/{id}/like', [PetController::class, 'swipeLike'])->whereNumber('id');

        // Pet Management (Owner/Shelter CRUD)
        Route::get('/my-pets', [PetController::class, 'myPets']);
        Route::post('/pets', [PetController::class, 'store']);
        Route::put('/pets/{id}', [PetController::class, 'update']);
        Route::delete('/pets/{id}', [PetController::class, 'destroy']);

        // Formal Adoption Workflow
        Route::post('/adoption-requests', [AdoptionRequestController::class, 'store']);
        Route::get('/adoption-requests', [AdoptionRequestController::class, 'index']);
        Route::get('/adoption-requests/{id}', [AdoptionRequestController::class, 'show']);
        Route::patch('/adoption-requests/{id}/status', [AdoptionRequestController::class, 'updateStatus']);

        // Direct Messaging & Rescuer Chat
        Route::get('/messages/conversations', [MessageController::class, 'getConversations']);
        Route::get('/messages/{userId}', [MessageController::class, 'getMessages']);
        Route::post('/messages', [MessageController::class, 'sendMessage']);
    });
});
