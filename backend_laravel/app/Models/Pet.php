<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Pet extends Model
{
    use HasFactory;

    protected $fillable = [
        'owner_id',
        'name',
        'species',
        'breed',
        'age_months',
        'gender',
        'size',
        'vaccination_status',
        'is_spayed_neutered',
        'description',
        'medical_history',
        'adoption_fee',
        'location_lat',
        'location_lng',
        'location_city',
        'adoption_status',
        'qr_hash',
        'match_score',
    ];

    protected $appends = ['primary_image_url', 'age_display'];

    protected function casts(): array
    {
        return [
            'age_months' => 'integer',
            'is_spayed_neutered' => 'boolean',
            'adoption_fee' => 'float',
            'location_lat' => 'float',
            'location_lng' => 'float',
            'match_score' => 'integer',
        ];
    }

    public function owner()
    {
        return $this->belongsTo(User::class, 'owner_id');
    }

    public function images()
    {
        return $this->hasMany(PetImage::class);
    }

    public function primaryImage()
    {
        return $this->hasOne(PetImage::class)->where('is_primary', true);
    }

    public function favorites()
    {
        return $this->hasMany(Favorite::class);
    }

    public function adoptionRequests()
    {
        return $this->hasMany(AdoptionRequest::class);
    }

    public function getPrimaryImageUrlAttribute(): ?string
    {
        $primary = $this->images->firstWhere('is_primary', true) ?? $this->images->first();
        return $primary ? $primary->image_url : null;
    }

    public function getAgeDisplayAttribute(): string
    {
        if ($this->age_months < 12) {
            return "{$this->age_months} mos";
        }
        $years = floor($this->age_months / 12);
        return $years == 1 ? "1 year" : "{$years} years";
    }
}

