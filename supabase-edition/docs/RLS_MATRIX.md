# RLS matrix

Every table has Row Level Security enabled. `service_role` bypasses RLS and is
used only by Edge Functions after they have authenticated the caller.

Role is read from the JWT claim `app_role`, injected by
`public.custom_access_token_hook`. Helper names below live in the `private`
schema and are not reachable through PostgREST.

| Table | anon | authenticated (owner) | staff |
|---|---|---|---|
| `profiles` | — | read/update own (role and `is_verified` reverted by trigger) | read/update all |
| `public_profiles` (view) | read | read | read |
| `shelters` | read approved | read own, create, update, delete own | read/update/delete all |
| `pets` | read approved + active | read own, create (`pending` forced), update own, delete own | read/update/delete all, approve, feature |
| `pet_images` | read with visible pet | write for own pet | write any |
| `favorites`, `swipes` | — | own rows only | own rows only |
| `adoption_requests` | — | applicant read/insert/withdraw; listing owner reviews | read/update/delete |
| `appointments` | — | requester + host | all |
| `conversations` | — | participants; adopter may open a thread with the real listing owner | read all |
| `messages` | — | participants; sender may insert; only `read_at` is mutable | read all |
| `community_posts` | read approved | read/insert own/update/delete own | moderate/delete |
| `post_likes`, `post_comments` | — | read; own rows | delete any comment |
| `subscription_plans` | read active | read active | read |
| `payments` | — | read own | read all (writes: service role only) |
| `subscriptions` | — | read own | read all (writes: service role only) |
| `health_passports`, `vaccine_records` | — | owner of the pet | read/update |
| `emergency_alerts` | read active | read active, create, update/delete own | all |
| `device_tokens`, `notifications` | — | own rows | push via function |
| `audit_logs` | — | — | read (writes: service role only) |

## Storage

| Bucket | Public | Read | Write |
|---|---|---|---|
| `pet-images` | yes | anyone | `{user_id}/...` or staff |
| `avatars` | yes | anyone | `{user_id}/...` |
| `chat-attachments` | no | conversation participants | `{conversation_id}/{user_id}/...` |
| `application-docs` | no | applicant, listing owner, staff | `{application_id}/{user_id}/...` |

## Guard triggers

Policies cannot compare `old` and `new`, so the invariants that need both live in
triggers:

| Trigger | Protects |
|---|---|
| `profiles_guard_role` | self-promotion (role, `is_verified`) |
| `pets_guard_moderation` | self-approval, self-featuring, owner reassignment |
| `shelters_guard_verification` | self-verification, self-rating |
| `adoption_requests_guard_transitions` | applicants can only withdraw; decisions need notes |
| `emergency_alerts_guard_ownership` | resolving someone else's alert |
| `messages_guard_immutability` | editing a sent message |
| `on_auth_user_created` | sign-up metadata cannot set a role |

All guards call `private.bypasses_guards()` first, which is true for the service
role (Edge Functions) and for a direct `postgres` session (migrations, seed).
Without that, a guard would fight the very function that is supposed to change
the field.

## Known limits

- A ban blocks new sign-ins immediately, but an access token already issued stays
  valid until it expires (one hour by default). Lower `jwt_expiry` if that
  window matters.
- `community_posts` default to `approved` so a small community has no dead feed;
  staff can flip a post to `rejected`. Change the default to `pending` if you
  prefer pre-moderation.
- RLS is only as good as the policies; `supabase test db` plus the checklist in
  `docs/DEPLOY.md` is the intended verification path.
