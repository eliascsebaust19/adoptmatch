<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('favorites', function (Blueprint $table) {
            // Existing likes/dislikes are not silently converted into saved favorites.
            $table->boolean('is_favorite')->default(false)->after('swipe_direction');
            $table->index(['user_id', 'is_favorite']);
        });
        Schema::table('messages', function (Blueprint $table) {
            $table->string('attachment_url', 2048)->nullable()->after('message_text');
        });
    }

    public function down(): void
    {
        Schema::table('favorites', function (Blueprint $table) {
            $table->dropIndex(['user_id', 'is_favorite']);
            $table->dropColumn('is_favorite');
        });
        Schema::table('messages', function (Blueprint $table) {
            $table->dropColumn('attachment_url');
        });
    }
};
