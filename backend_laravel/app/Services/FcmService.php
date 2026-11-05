<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

class FcmService
{
    /**
     * Send push notification via Firebase Cloud Messaging (FCM).
     */
    public static function sendNotification(?string $deviceToken, string $title, string $body, array $data = []): bool
    {
        if (empty($deviceToken)) {
            Log::info("[FCM] Skipped: No device token provided for notification: {$title}");
            return false;
        }

        $serverKey = env('FCM_SERVER_KEY');

        if (empty($serverKey)) {
            // Simulated FCM notification delivery (Useful for testing without live Firebase project)
            Log::info("[FCM Simulated Delivery] To: {$deviceToken} | Title: {$title} | Body: {$body}", $data);
            return true;
        }

        try {
            $response = Http::withHeaders([
                'Authorization' => 'key=' . $serverKey,
                'Content-Type' => 'application/json',
            ])->post('https://fcm.googleapis.com/fcm/send', [
                'to' => $deviceToken,
                'notification' => [
                    'title' => $title,
                    'body' => $body,
                    'sound' => 'default',
                    'icon' => 'notification_icon',
                ],
                'data' => $data,
                'priority' => 'high',
            ]);

            Log::info("[FCM Sent] Response status: " . $response->status());
            return $response->successful();
        } catch (\Exception $e) {
            Log::error("[FCM Error] " . $e->getMessage());
            return false;
        }
    }
}
