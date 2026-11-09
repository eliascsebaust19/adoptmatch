# Mapping: Laravel/Node endpoints → Supabase edition

Use this when porting the Flutter repositories. Every Laravel route has a direct
replacement; nothing here needs a new custom API.

## Auth

| Before | Now |
|---|---|
| `POST /api/v1/auth/register` | `auth.signUp(email:, password:, data: {'full_name': ...})` |
| `POST /api/v1/auth/login` | `auth.signInWithPassword(...)` |
| `POST /api/v1/auth/google` (ID token → Sanctum) | `auth.signInWithIdToken(provider: google, idToken: ...)` |
| `POST /api/v1/auth/phone/request` | `auth.signInWithOtp(phone: ...)` |
| `POST /api/v1/auth/phone/verify` | `auth.verifyOTP(phone:, token:, type: OtpType.sms)` |
| `GET /api/v1/me` | `from('profiles').select().eq('id', user.id).single()` |
| `POST /api/v1/auth/logout` | `auth.signOut()` |
| `POST /api/v1/auth/password` | `auth.updateUser(UserAttributes(password: ...))` |

The bearer token in `ApiClient` goes away: `supabase_flutter` attaches the access
token to every PostgREST/Storage/Function call by itself.

## Pets and discovery

| Before | Now |
|---|---|
| `GET /api/v1/pets` | `from('pets_feed').select()` (filters = `.eq/.or/.order`) |
| `GET /api/v1/pets/{id}` | `from('pets_feed').select().eq('id', id).single()` |
| `GET /api/v1/pets/nearby` | `rpc('pets_nearby', params: {p_lat, p_lng, p_radius_km, p_limit})` |
| `GET /api/v1/pets/swipe-stack` | `from('pets_feed').select().not('id','in', swipedIds)` |
| `POST /api/v1/pets` | `from('pets').insert(...)` (moderation forced to `pending`) |
| `PUT /api/v1/pets/{id}` | `from('pets').update(...)` |
| `POST /api/v1/pets/{id}/like` | `from('swipes').upsert({...})` |
| `PUT /api/v1/pets/{id}/favorite` | `from('favorites').upsert({...})` |
| `POST /api/v1/upload/image` | `storage.from('pet-images').uploadBinary('{uid}/{petId}/file', bytes)` |

## Adoption, chat, community

| Before | Now |
|---|---|
| `POST /api/v1/adoption-requests` | `from('adoption_requests').insert({pet_id, applicant_id, applicant_data, signature_data, is_e_signed})` |
| `GET /api/v1/adoption-requests` | `from('adoption_requests').select()` (RLS scopes it) |
| `PATCH /api/v1/adoption-requests/{id}/status` | `update({status, reviewer_notes})` — trigger enforces who may decide |
| `GET /api/v1/messages/conversations` | `from('conversations').select()` |
| `GET /api/v1/messages/{userId}` | `from('messages').select().eq('conversation_id', ...)` |
| `POST /api/v1/messages` | `from('messages').insert(...)`; live updates via `.stream()` |
| Community feed | `from('community_posts').select()` + `post_likes` / `post_comments` |

## Money

| Before | Now |
|---|---|
| `GET /api/v1/payments/plans` | `from('subscription_plans').select()` or `payments/plans` |
| `POST /api/v1/payments/initiate-sslcommerz` | `functions.invoke('payments/initiate-sslcommerz', body: {plan_id})` |
| `POST /api/v1/payments/manual-bkash` | `functions.invoke('payments/manual-bkash', body: {plan_id, trx_id, sender_phone})` |
| `GET /api/v1/payments/my-subscription` | `functions.invoke('payments/my-subscription')` |
| `GET /api/v1/payments/verify/{tranId}` | `functions.invoke('payments/verify/{tranId}')` |
| `POST /api/v1/payments/sslcommerz-success|fail|cancel|ipn` | handled inside the `payments` function, no app code |
| `GET /api/v1/subscriptions/plans` | same table |

## Admin

| Before | Now |
|---|---|
| `GET /api/v1/admin/stats` | `functions.invoke('admin/stats')` |
| `GET /api/v1/admin/users` | `functions.invoke('admin/users?q=&role=&limit=')` |
| `PATCH /api/v1/admin/users/{id}` | `functions.invoke('admin/users/{id}', body: {role, status})` |
| `GET /api/v1/admin/pets` | `functions.invoke('admin/pets?moderation=pending')` |
| `POST /api/v1/admin/pets/{id}/moderate` | `functions.invoke('admin/pets/{id}', body: {moderation_status})` |
| `GET /api/v1/admin/shelters` | `functions.invoke('admin/shelters')` |
| `POST /api/v1/admin/shelters/{id}/approve` | `functions.invoke('admin/shelters/{id}', body: {verification_status: 'approved'})` |
| `POST /api/v1/payments/manual-bkash/{tranId}/approve` | `functions.invoke('admin/payments/{tranId}/approve')` |
| `GET /api/v1/admin/audit-logs` | `functions.invoke('admin/audit-logs')` |

## Fields the Flutter models expect

`UserProfile.fromJson` reads `premiumExpiresAt`, `isPremium`, `role`, `avatarUrl`,
`isVerified`. In this edition those come from two places:

```dart
final profile = await backend.myProfile();          // role, avatar_url, is_verified
final sub = await backend.mySubscription();         // is_premium, plan_id, expires_at
```

Build the model with `isPremium: sub.subscription['is_premium']`,
`premiumExpiresAt: DateTime.parse(sub.subscription['expires_at'])`.

`Pet` maps from `pets_feed` row-for-row: `age_months`, `shelter_name`,
`shelter_phone`, `is_favorite`, `adoption_status`, `distance_km` (only from
`pets_nearby`, computed client-side otherwise).
