<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('favorites', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained('users')->onDelete('cascade');
            $table->foreignId('pet_id')->constrained('pets')->onDelete('cascade');
            $table->enum('swipe_direction', ['like', 'dislike'])->default('like');
            $table->timestamps();

            $table->unique(['user_id', 'pet_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('favorites');
    }
};

