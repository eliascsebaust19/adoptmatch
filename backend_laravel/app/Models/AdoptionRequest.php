<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class AdoptionRequest extends Model
{
    use HasFactory;

    protected $fillable = [
        'reference_no',
        'pet_id',
        'requester_id',
        'owner_id',
        'status',
        'applicant_data',
        'reviewer_notes',
        'home_visit_date',
        'is_signed',
        'signature_data',
    ];

    protected function casts(): array
    {
        return [
            'applicant_data' => 'array',
            'home_visit_date' => 'datetime',
            'is_signed' => 'boolean',
        ];
    }

    public function pet()
    {
        return $this->belongsTo(Pet::class);
    }

    public function requester()
    {
        return $this->belongsTo(User::class, 'requester_id');
    }

    public function owner()
    {
        return $this->belongsTo(User::class, 'owner_id');
    }
}

