<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('pets', function (Blueprint $table) {
            $table->id();
            $table->foreignId('owner_id')->constrained('users')->onDelete('cascade');
            $table->string('name');
            $table->string('species'); // dog, cat, rabbit, bird, etc.
            $table->string('breed');
            $table->integer('age_months')->default(12);
            $table->enum('gender', ['male', 'female', 'unknown'])->default('unknown');
            $table->enum('size', ['small', 'medium', 'large', 'giant'])->default('medium');
            $table->string('vaccination_status')->default('fully_vaccinated');
            $table->boolean('is_spayed_neutered')->default(true);
            $table->text('description')->nullable();
            $table->text('medical_history')->nullable();
            $table->decimal('adoption_fee', 8, 2)->default(0.00);
            $table->decimal('location_lat', 10, 8)->nullable()->index();
            $table->decimal('location_lng', 11, 8)->nullable()->index();
            $table->string('location_city')->nullable();
            $table->enum('adoption_status', ['available', 'pending', 'adopted'])->default('available')->index();
            $table->string('qr_hash')->nullable()->unique();
            $table->integer('match_score')->default(90);
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('pets');
    }
};

