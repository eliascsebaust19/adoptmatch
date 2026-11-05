<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    use HasApiTokens, HasFactory, Notifiable;

    protected $fillable = [
        'name',
        'email',
        'google_id',
        'avatar',
        'phone',
        'role',
        'location_lat',
        'location_lng',
        'password',
    ];

    protected $hidden = [
        'password',
        'remember_token',
    ];

    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'password' => 'hashed',
            'location_lat' => 'float',
            'location_lng' => 'float',
        ];
    }

    public function shelter()
    {
        return $this->hasOne(Shelter::class);
    }

    public function pets()
    {
        return $this->hasMany(Pet::class, 'owner_id');
    }

    public function favorites()
    {
        return $this->hasMany(Favorite::class);
    }

    public function adoptionRequests()
    {
        return $this->hasMany(AdoptionRequest::class, 'requester_id');
    }

    public function receivedAdoptionRequests()
    {
        return $this->hasMany(AdoptionRequest::class, 'owner_id');
    }

    public function sentMessages()
    {
        return $this->hasMany(Message::class, 'sender_id');
    }

    public function receivedMessages()
    {
        return $this->hasMany(Message::class, 'receiver_id');
    }
}

