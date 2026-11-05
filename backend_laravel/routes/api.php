<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\PetController;
use App\Http\Controllers\Api\AdoptionRequestController;
use App\Http\Controllers\Api\MessageController;

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
    });

    // Public Pet Catalog & Details
    Route::get('/pets', [PetController::class, 'index']);
    Route::get('/pets/{id}', [PetController::class, 'show'])->whereNumber('id');

    // =====================================
    // 2. PROTECTED ROUTES (SANCTUM BEARER)
    // =====================================
    Route::middleware('auth:sanctum')->group(function () {

        // User & Session
        Route::get('/me', [AuthController::class, 'me']);
        Route::post('/auth/logout', [AuthController::class, 'logout']);

        // Tinder Pet Matching & Swiping
        Route::get('/pets/swipe-stack', [PetController::class, 'getSwipeStack']);
        Route::post('/pets/{id}/like', [PetController::class, 'swipeLike']);
        Route::get('/pets/nearby', [PetController::class, 'getNearbyPets']);

        // Pet Management (Owner/Shelter CRUD)
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

