<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Shelter extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'organization_name',
        'license_number',
        'verification_document',
        'address',
        'phone',
        'rating',
        'is_verified',
    ];

    protected function casts(): array
    {
        return [
            'rating' => 'float',
            'is_verified' => 'boolean',
        ];
    }

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}

