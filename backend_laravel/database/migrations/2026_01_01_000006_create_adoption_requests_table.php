<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('adoption_requests', function (Blueprint $table) {
            $table->id();
            $table->string('reference_no')->unique(); // AM-APP-xxxxx
            $table->foreignId('pet_id')->constrained('pets')->onDelete('cascade');
            $table->foreignId('requester_id')->constrained('users')->onDelete('cascade');
            $table->foreignId('owner_id')->constrained('users')->onDelete('cascade');
            $table->enum('status', [
                'submitted',
                'under_review',
                'home_visit',
                'foster_trial',
                'approved',
                'rejected'
            ])->default('submitted')->index();
            $table->json('applicant_data'); // Complete 28-field Adoption Dossier
            $table->text('reviewer_notes')->nullable();
            $table->dateTime('home_visit_date')->nullable();
            $table->boolean('is_signed')->default(true);
            $table->text('signature_data')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('adoption_requests');
    }
};

