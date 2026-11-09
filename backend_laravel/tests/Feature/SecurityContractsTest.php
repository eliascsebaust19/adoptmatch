<?php

namespace Tests\Feature;

use App\Models\AdoptionRequest;
use App\Models\Message;
use App\Models\Pet;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Http;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class SecurityContractsTest extends TestCase
{
    use RefreshDatabase;

    private function user(string $email, string $role = 'adopter'): User
    {
        return User::create(['name' => 'Test User', 'email' => $email, 'role' => $role,
            'password' => bcrypt('correct-password')]);
    }

    private function pet(User $owner): Pet
    {
        return Pet::create(['owner_id' => $owner->id, 'name' => 'Luna', 'species' => 'dog',
            'breed' => 'Mixed', 'age_months' => 12, 'gender' => 'female', 'size' => 'medium',
            'vaccination_status' => 'unknown', 'description' => 'Rescue', 'adoption_status' => 'available']);
    }

    public function test_protected_writes_reject_guests(): void
    {
        $this->postJson('/api/v1/upload/image')->assertUnauthorized();
        $this->putJson('/api/v1/pets/1/favorite')->assertUnauthorized();
        $this->postJson('/api/v1/messages', [])->assertUnauthorized();
        $this->postJson('/api/v1/adoption-requests', [])->assertUnauthorized();
    }

    public function test_favorites_are_persistent_and_separate_from_swipes(): void
    {
        $user = $this->user('fav@example.test'); $pet = $this->pet($this->user('owner@example.test'));
        Sanctum::actingAs($user, ['*']);
        $this->postJson("/api/v1/pets/{$pet->id}/like", ['direction' => 'dislike'])->assertOk();
        $this->getJson("/api/v1/pets/{$pet->id}/favorite")->assertOk()->assertJsonPath('data.is_favorite', false);
        $this->putJson("/api/v1/pets/{$pet->id}/favorite")->assertOk()->assertJsonPath('data.is_favorite', true);
        $this->getJson('/api/v1/favorites')->assertOk()->assertJsonCount(1, 'data');
        $this->deleteJson("/api/v1/pets/{$pet->id}/favorite")->assertOk()->assertJsonPath('data.is_favorite', false);
        $this->assertDatabaseHas('favorites', ['user_id' => $user->id, 'pet_id' => $pet->id, 'is_favorite' => false]);
    }

    public function test_messages_bind_sender_and_persist_attachments(): void
    {
        $sender = $this->user('sender@example.test'); $receiver = $this->user('receiver@example.test');
        Sanctum::actingAs($sender, ['*']);
        $this->postJson('/api/v1/messages', ['receiver_id' => $receiver->id, 'sender_id' => $receiver->id,
            'message_text' => 'spoof'])->assertUnprocessable();
        $this->postJson('/api/v1/messages', ['receiver_id' => $sender->id, 'message_text' => 'self'])->assertUnprocessable();
        $this->postJson('/api/v1/messages', ['receiver_id' => $receiver->id, 'message_text' => 'Hello',
            'attachment_url' => 'https://cdn.example.test/home.jpg'])->assertCreated()
            ->assertJsonPath('data.sender_id', $sender->id);
        $this->assertDatabaseHas('messages', ['sender_id' => $sender->id, 'receiver_id' => $receiver->id,
            'attachment_url' => 'https://cdn.example.test/home.jpg']);
        $this->getJson("/api/v1/messages/{$receiver->id}")->assertOk()->assertJsonCount(1, 'data');
    }

    private function dossier(): array
    {
        return ['pet_id' => 0, 'signature_data' => '{"strokes":[[[1,2],[3,4]]]}',
            'applicant_data' => ['applicantName' => 'Applicant', 'applicantPhone' => '+8801700000000',
                'applicantEmail' => 'applicant@example.test', 'address' => 'Dhaka', 'housingType' => 'Apartment',
                'nidNumber' => '1234567890', 'emergencyContactName' => 'Contact',
                'emergencyContactPhone' => '+8801800000000', 'landlordAllowsPets' => true,
                'whyAdopt' => 'A safe permanent home.']];
    }

    public function test_adoption_requires_signature_and_acknowledged_reference(): void
    {
        $owner = $this->user('owner2@example.test'); $pet = $this->pet($owner);
        $applicant = $this->user('applicant@example.test'); Sanctum::actingAs($applicant, ['*']);
        $data = $this->dossier(); $data['pet_id'] = $pet->id;
        unset($data['signature_data']);
        $this->postJson('/api/v1/adoption-requests', $data)->assertUnprocessable();
        $data['signature_data'] = '{"strokes":[[[1,2],[3,4]]]}';
        $response = $this->postJson('/api/v1/adoption-requests', $data)->assertCreated()
            ->assertJsonPath('status', 'success');
        $this->assertNotEmpty($response->json('reference_no'));
        $this->postJson('/api/v1/adoption-requests', $data)->assertConflict();
        $id = $response->json('data.id');
        $this->patchJson("/api/v1/adoption-requests/{$id}/status", ['status' => 'under_review'])->assertNotFound();
        Sanctum::actingAs($owner, ['*']);
        $this->patchJson("/api/v1/adoption-requests/{$id}/status", ['status' => 'under_review'])->assertOk();
        $this->assertDatabaseHas('adoption_requests', ['id' => $id, 'status' => 'under_review']);
    }

    public function test_self_adoption_is_rejected(): void
    {
        $owner = $this->user('selfowner@example.test'); $pet = $this->pet($owner);
        Sanctum::actingAs($owner, ['*']);
        $data = $this->dossier(); $data['pet_id'] = $pet->id;
        $this->postJson('/api/v1/adoption-requests', $data)->assertUnprocessable();
    }

    public function test_upload_requires_genuine_image_and_confirms_local_bytes(): void
    {
        $user = $this->user('upload@example.test'); Sanctum::actingAs($user, ['*']);
        config(['services.cloudinary' => ['cloud_name' => null, 'api_key' => null, 'api_secret' => null]]);
        $fake = UploadedFile::fake()->createWithContent('fake.png', 'not an image');
        $this->post('/api/v1/upload/image', ['image' => $fake], ['Accept' => 'application/json'])->assertStatus(415);
        $png = base64_decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=');
        $tmp = tempnam(sys_get_temp_dir(), 'img'); file_put_contents($tmp, $png);
        $image = new UploadedFile($tmp, 'real.png', 'image/png', null, true);
        $response = $this->post('/api/v1/upload/image', ['image' => $image, 'folder' => 'pets'], ['Accept' => 'application/json'])
            ->assertCreated()->assertJsonPath('status', 'success')->assertJsonPath('bytes', strlen($png));
        $this->assertStringContainsString('/uploads/pets/', $response->json('url'));
        $files = glob(public_path('uploads/pets/'.$user->id.'-*.png'));
        $this->assertNotEmpty($files);
        $this->assertSame($png, file_get_contents($files[0]));
        foreach ($files as $file) { @unlink($file); }
    }

    public function test_my_pets_returns_only_authenticated_owner_listings(): void
    {
        $owner = $this->user('mine@example.test'); $other = $this->user('other@example.test');
        $mine = $this->pet($owner); $this->pet($other);
        Sanctum::actingAs($owner, ['*']);
        $this->getJson('/api/v1/my-pets')->assertOk()->assertJsonCount(1, 'data.data')
            ->assertJsonPath('data.data.0.id', $mine->id);
    }

    public function test_password_change_requires_authentication(): void
    {
        $this->postJson('/api/v1/auth/password', [])->assertUnauthorized();
    }

    public function test_password_change_requires_the_correct_current_password(): void
    {
        $user = $this->user('pw@example.test');
        Sanctum::actingAs($user, ['*']);
        $this->postJson('/api/v1/auth/password', ['current_password' => 'wrong-password',
            'password' => 'brand-new-password', 'password_confirmation' => 'brand-new-password'])
            ->assertStatus(422);
        $this->assertTrue(\Illuminate\Support\Facades\Hash::check('correct-password', $user->fresh()->password));
    }

    public function test_password_change_updates_the_hash_and_revokes_other_sessions(): void
    {
        $user = $this->user('pw2@example.test');
        $user->createToken('other-device');
        Sanctum::actingAs($user, ['*']);
        $this->postJson('/api/v1/auth/password', ['current_password' => 'correct-password',
            'password' => 'brand-new-password', 'password_confirmation' => 'brand-new-password'])
            ->assertOk()->assertJsonPath('status', 'success');
        $this->assertTrue(\Illuminate\Support\Facades\Hash::check('brand-new-password', $user->fresh()->password));
        $this->assertSame(0, $user->tokens()->count(), 'other personal access tokens are revoked');
    }

    public function test_public_registration_cannot_self_assign_shelter_role(): void
    {
        $this->postJson('/api/v1/auth/register', ['name' => 'Shelter Attempt',
            'email' => 'shelter-attempt@example.test', 'password' => 'password123', 'role' => 'shelter'])
            ->assertUnprocessable();
    }

    public function test_google_login_rejects_unverified_token(): void
    {
        config(['services.google.client_id' => 'test-client.apps.googleusercontent.com']);
        $this->postJson('/api/v1/auth/google', ['id_token' => 'not-a-google-token'])->assertUnauthorized();
    }

    public function test_phone_otp_request_uses_configured_provider(): void
    {
        config(['services.supabase' => ['url' => 'https://project.supabase.co', 'anon_key' => 'test-anon-key']]);
        Http::fake(['*/auth/v1/otp' => Http::response([], 200)]);
        $this->postJson('/api/v1/auth/phone/request', ['phone' => '+8801700000000'])
            ->assertOk()->assertJsonPath('status', 'success');
    }

    public function test_phone_otp_fails_closed_without_provider(): void
    {
        config(['services.supabase' => ['url' => null, 'anon_key' => null]]);
        $this->postJson('/api/v1/auth/phone/request', ['phone' => '+8801700000000'])->assertStatus(503);
    }

    public function test_phone_otp_checks_provider_phone_before_issuing_sanctum_token(): void
    {
        config(['services.supabase' => ['url' => 'https://project.supabase.co', 'anon_key' => 'test-anon-key']]);
        Http::fake([
            '*/auth/v1/verify' => Http::sequence()
                ->push(['access_token' => 'provider-token', 'user' => ['id' => 'supabase-user', 'phone' => '+8801700000001']], 200)
                ->push(['access_token' => 'provider-token', 'user' => ['id' => 'supabase-user', 'phone' => '+8801700000000']], 200),
        ]);
        $this->postJson('/api/v1/auth/phone/verify', ['phone' => '+8801700000000', 'token' => '123456'])->assertUnauthorized();
        $this->postJson('/api/v1/auth/phone/verify', ['phone' => '+8801700000000', 'token' => '123456'])
            ->assertOk()->assertJsonStructure(['access_token', 'user' => ['id']]);
        $this->assertDatabaseHas('users', ['supabase_id' => 'supabase-user', 'phone' => '+8801700000000']);
    }
}
