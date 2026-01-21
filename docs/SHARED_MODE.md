# Shared Mode (Communal iPad) – Implementation Plan + Spec

## Goal
Provide a **staff-managed “Shared Mode”** for communal devices (e.g., an iPad at a location) where:

- Staff can quickly switch the “active user” using **Name + PIN**.
- While Shared Mode is enabled, the device stays in a **tasks-only UI** (User Dashboard).
- **Exiting Shared Mode back to the original/owner account requires the owner PIN**.
- If the owner PIN is not available, the only safe escape hatch is **full device sign-out** (returns to login).

This is a **device-level mode** (persisted locally) that changes UI access and task attribution.

## Non-goals (for initial rollout)
- Perfect anti-tamper security on a physically accessible device.
- Full kiosk-mode restrictions at OS level.
- Replacing FirebaseAuth sessions with a custom auth system.

## Key Concepts

### Owner
The authenticated user who enables Shared Mode on the device.

### Active Actor
The staff member currently “checked in” on the shared device.

- Task completion attribution should use the active actor when Shared Mode is enabled.
- If Shared Mode is enabled but no active actor is selected, the app is **locked**.

### Locked State
Shared Mode is enabled but no active actor is selected (or inactivity auto-lock has kicked in).

- UI is blocked by a lock overlay.
- Staff must pick their name and enter their PIN.

## UX Flows

### 1) Set/Change PIN (per staff account)
- Entry point: menu item **Shared Mode PIN**
- Staff sets a 4–10 digit numeric PIN.
- Backend stores only a salted hash (never the PIN).

### 2) Enter Shared Mode (owner enables)
- Entry point: menu item **Enter Shared Mode**
- Device persists:
  - `enabled=true`
  - `ownerUserId`
  - `ownerOrgId`
  - `locationId`
- App navigates to **User Dashboard** and becomes **locked** until an active actor is selected.

### 3) Select user (unlock)
- Lock overlay shows staff list for the current org + location.
- Staff selects their name, enters PIN.
- App sets active actor info in Shared Mode state.

### 4) Switch user
- Entry point: menu item **Switch user**
- App locks and returns to user picker overlay.

### 5) Auto-lock on inactivity
- After inactivity timeout (currently 90s), Shared Mode locks.
- Any pointer/tap activity on User Dashboard resets the timer.

### 6) Leave Shared Mode
- Entry point: menu item **Leave Shared Mode**
- Requires owner PIN verification.
- If verified: Shared Mode state cleared and normal navigation/UI restored.

### 7) Sign out device (fail-safe)
- Entry point: menu item **Sign out device**
- Clears Shared Mode state and signs out FirebaseAuth.

## Data Model

### Public user doc
`users/{userId}`

- `hasSharedModePin: true|false`
- Existing location membership fields are used for eligibility:
  - `locationIds: [locationId]` (preferred)
  - or legacy `locationId: locationId`

### Private PIN hash storage
`users/{userId}/preferences/sharedMode`

- `pinSalt: string`
- `pinHash: string`

Security rules already restrict `/users/{userId}/preferences/*` to the user themself; Cloud Functions read it as admin.

## Backend API (Cloud Functions – callable)

### `sharedModeSetPin`
Sets/updates the PIN for the current authenticated user.

- Input: `{ pin: string }`
- Validations: numeric, 4–10 digits
- Writes:
  - `users/{uid}/preferences/sharedMode` (`pinSalt`, `pinHash`)
  - `users/{uid}.hasSharedModePin = true`

### `sharedModeVerifyPin`
Verifies a PIN for a target user, constrained to org and location.

- Input: `{ targetUserId: string, pin: string, orgId: string, locationId: string }`
- Verifies:
  - Caller is authenticated
  - Target user belongs to `orgId`
  - Target user is eligible for `locationId` (via `locationIds`/`locationId`)
  - PIN matches stored hash
- Output on success: `{ ok: true, userId, displayName, email }`
- Output on failure: `{ ok: false }`

Owner-exit verification reuses this callable by setting `targetUserId = ownerUserId`.

## Client Architecture

### Device persistence (SharedPreferences)
Persisted keys (device-scoped):

- `sharedMode.enabled`
- `sharedMode.ownerUserId`
- `sharedMode.ownerOrgId`
- `sharedMode.locationId`

### State + controller
- Shared Mode state is held in a Riverpod controller.
- Controller responsibilities:
  - enter/disable shared mode
  - lock/unlock
  - inactivity timer
  - eligible user stream
  - PIN callable integration
  - completion actor selection

### UI integration
- User Dashboard overlays a lock screen when Shared Mode is enabled + locked.
- Bottom navigation is hidden during Shared Mode.
- Router-level redirect forces all navigation to User Dashboard when Shared Mode is enabled.

## Phased Rollout Plan

### Phase 1 – Backend PIN support
- Add callable functions:
  - `sharedModeSetPin`
  - `sharedModeVerifyPin`
- Store PIN hash/salt under private preferences doc
- Set `hasSharedModePin` flag for eligibility query

### Phase 2 – Client Shared Mode core
- Shared Mode state/controller persisted on device
- Lock overlay (user selection + PIN entry)
- Inactivity auto-lock

### Phase 3 – Expose actions in UI
- Menu items:
  - **Shared Mode PIN**
  - **Enter Shared Mode**
  - While enabled: **Switch user**, **Leave Shared Mode**, **Sign out device**

### Phase 4 – Route restrictions
- Router redirect forces tasks-only UI during Shared Mode

### Phase 5 – Attribution coverage
- Ensure all task completion and other writes use `completionActor()`

### Phase 6 – QA + release
- Verify for:
  - staff/manager/admin roles
  - multiple locations
  - device restart persistence
  - offline behavior (fail closed → locked)

## Current Implementation Status (as of this change)
- Shared Mode controller/state/lock overlay created and integrated into User Dashboard.
- Popup menu updated with Shared Mode actions.
- Router redirect updated to force tasks-only UI during Shared Mode.
- Cloud Functions for PIN set/verify added.

## Open Items / Follow-ups
- Ensure all task write paths (not just some) use Shared Mode actor attribution.
- Consider adding a Firestore composite index if needed for `users` query on `organizationId + hasSharedModePin`.
- Add owner/org/location mismatch handling if owner changes location while in Shared Mode.
