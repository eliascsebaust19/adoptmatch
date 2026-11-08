<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Message;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

class MessageController extends Controller
{
    /**
     * List all Active Conversation Threads for the Current User.
     */
    public function getConversations(Request $request)
    {
        $userId = $request->user()->id;

        $conversations = Message::where('sender_id', $userId)
            ->orWhere('receiver_id', $userId)
            ->with(['sender:id,name,avatar', 'receiver:id,name,avatar', 'pet:id,name,species'])
            ->orderBy('created_at', 'desc')
            ->get()
            ->groupBy(function ($msg) use ($userId) {
                return $msg->sender_id === $userId ? $msg->receiver_id : $msg->sender_id;
            })
            ->map(function ($msgs) use ($userId) {
                $lastMsg = $msgs->first();
                $otherUser = $lastMsg->sender_id === $userId ? $lastMsg->receiver : $lastMsg->sender;
                $unreadCount = $msgs->where('receiver_id', $userId)->where('is_read', false)->count();

                return [
                    'other_user' => $otherUser,
                    'last_message' => $lastMsg->message_text,
                    'last_message_time' => $lastMsg->created_at->toIso8601String(),
                    'unread_count' => $unreadCount,
                    'pet' => $lastMsg->pet,
                ];
            })
            ->values();

        return response()->json([
            'status' => 'success',
            'data' => $conversations,
        ], 200);
    }

    /**
     * Get Full Message History between Current User and Another User.
     */
    public function getMessages(Request $request, $otherUserId)
    {
        $userId = $request->user()->id;

        // Mark unread messages as read
        Message::where('sender_id', $otherUserId)
            ->where('receiver_id', $userId)
            ->where('is_read', false)
            ->update(['is_read' => true]);

        $messages = Message::where(function ($q) use ($userId, $otherUserId) {
            $q->where('sender_id', $userId)->where('receiver_id', $otherUserId);
        })->orWhere(function ($q) use ($userId, $otherUserId) {
            $q->where('sender_id', $otherUserId)->where('receiver_id', $userId);
        })
        ->orderBy('created_at', 'asc')
        ->get();

        return response()->json([
            'status' => 'success',
            'data' => $messages,
        ], 200);
    }

    /**
     * Send a New Message.
     */
    public function sendMessage(Request $request)
    {
        $request->validate([
            'receiver_id' => ['required', 'integer', Rule::exists('users', 'id')],
            'sender_id' => 'prohibited',
            'pet_id' => 'nullable|integer|exists:pets,id',
            'message_text' => 'required|string|max:1000',
            'attachment_url' => 'nullable|url:http,https|max:2048',
        ]);

        if ((int) $request->receiver_id === (int) $request->user()->id) {
            return response()->json(['status' => 'error', 'message' => 'Choose a different recipient.'], 422);
        }
        $message = Message::create([
            'sender_id' => $request->user()->id,
            'receiver_id' => $request->receiver_id,
            'pet_id' => $request->pet_id,
            'message_text' => $request->message_text,
            'attachment_url' => $request->input('attachment_url'),
            'is_read' => false,
        ]);

        return response()->json([
            'status' => 'success',
            'message' => 'Message sent successfully',
            'data' => $message->load(['sender:id,name,avatar', 'receiver:id,name,avatar']),
        ], 201);
    }
}

