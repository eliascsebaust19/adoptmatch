---
name: flutter-pro-upgrade
description: Upgrades an existing Flutter app to a professional level without changing its current visual identity. Use when asked to polish the UI, add profile management, or separate admin and user panels with role-based access.
---

# Flutter Pro Upgrade

## Phase 0: Understand and lock the design (do this first, change nothing yet)
1. Read the whole project: pubspec.yaml, lib/ structure, routing, state management, auth, and backend/database usage.
2. Extract the existing design system into a short summary: colors, fonts, spacing, border radius, button and card styles, icon style. This is the LOCKED design. Do not change the brand colors, fonts, or overall look.
3. Show me that summary and your plan before making large changes.

## Phase 1: Improve the UI while keeping the design locked
- Centralize the existing look into one ThemeData (light, and dark if already present) plus reusable constants for colors, spacing, and text styles. Replace hardcoded values with these.
- Create reusable widgets (primary button, input field, card, loading, empty state, error state) based on the existing style.
- Improve spacing, alignment, consistency, responsiveness for small and large screens, and add smooth but subtle animations. Do not redesign screens from scratch.

## Phase 2: Profile management
- Profile screen: photo, name, email, phone, and other fields the app already uses.
- Edit profile with validation, photo upload/change, change password (for email login), and logout.
- Handle loading, error, and offline states properly.

## Phase 3: Admin and user separation
- Add a `role` field (user / admin) in the user model and database.
- Build two completely separate navigation trees and folders, e.g. lib/features/admin/ and lib/features/user/, each with its own home, screens, and routes.
- Route guard: after login, send the user to the correct panel by role. A normal user must never be able to open an admin screen, even by deep link.
- Enforce roles on the backend too (security rules, custom claims, or server-side checks). UI hiding alone is not security.
- Admin panel basics: dashboard with key stats, user list with search, ability to view/disable users, and management screens for the app's main data.

## Phase 4: Professional quality
- Keep clean folder structure and follow the state management already used in the project.
- Proper error handling, form validation, and no secrets hardcoded in code.
- Run `flutter analyze` and fix issues. Make sure the app builds and existing features still work.

## Output
- Work phase by phase, and summarize changed files after each phase.
- List any manual setup I must do (console settings, rules, keys).
- Ask me before making any decision that could change the existing design or data structure.

