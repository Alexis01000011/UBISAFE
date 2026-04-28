# Acceptance Tests — CU-02: Vendor GPS Presence
**Feature:** F3 — GPSService + VendorTracker  
**SDD refs:** §5.3.2.1 (gpsStatusProvider), §5.3.2.2 (VendorTracker), §7.3 (RTDB schema)  
**Pre-requisite:** Firebase emulators running (`firebase emulators:start --project demo-ubisafe`)

---

## Setup

1. Start emulators: `firebase emulators:start --project demo-ubisafe`
2. In `ubisafe_app`, ensure `kUseEmulators = true` (or the app is configured to point to localhost emulator ports).
3. Sign in two test accounts via emulator Auth UI (http://localhost:4000):
   - **Vendor A** (`vendor-a@test.com`, role = `vendedor`)
   - **Buyer B** (`buyer-b@test.com`, role = `comprador`)

---

## Scenario A — Node appears in RTDB when vendor starts transmission

**Steps:**
1. Open app as Vendor A and activate the vendor toggle (calls `GPSService.startTransmission(uid-A)`).
2. Open Firebase Emulator UI → RTDB → `/vendedores_activos/uid-A`.

**Expected:**
- Node exists with exactly 4 fields: `lat` (number), `lng` (number), `timestamp` (number > 0), `activo` (boolean = true).
- Fields appear within 5 seconds of activation.

---

## Scenario B — Node disappears when vendor stops transmission

**Steps:**
1. (Vendor A is transmitting — Scenario A complete.)
2. Vendor A deactivates the toggle (calls `GPSService.stopTransmission(uid-A)`).
3. Check RTDB emulator UI.

**Expected:**
- `/vendedores_activos/uid-A` node no longer exists.
- Disappears within 2 seconds.

---

## Scenario C — Buyer sees vendor appear and disappear in real time

**Steps:**
1. Open app as Buyer B on the map screen (subscribes to `vendorMarkersProvider`).
2. Vendor A activates transmission (within 4 km of Buyer B's position).
3. Watch Buyer B's map.

**Expected:**
- Vendor A's pin appears on Buyer B's map within a few seconds.
- When Vendor A deactivates (Scenario B), the pin disappears without reloading the screen.

---

## Scenario D — Vendor beyond 4 km is NOT shown on buyer's map

**Steps:**
1. Use emulator to manually write a RTDB node at a position > 4 km from Buyer B:
   ```json
   /vendedores_activos/uid-far: { "lat": 20.0, "lng": -99.0, "timestamp": 1700000000000, "activo": true }
   ```
   (Adjust coordinates so the distance from Buyer B > 4 km.)
2. Check Buyer B's map.

**Expected:**
- `uid-far` pin does NOT appear on Buyer B's map.
- `haversineKm(buyerLat, buyerLng, 20.0, -99.0) > 4.0` — confirm with unit test output.

---

## Scenario E — GPS service state transitions on OS GPS toggle

**Steps:**
1. Open app as Vendor A (GPS enabled, permission granted).
2. Confirm `gpsStatusProvider` emits `ready` (map screen is functional).
3. Turn off device GPS from system settings mid-session.
4. Observe the vendor screen.

**Expected:**
- `gpsStatusProvider` emits `serviceOff` → `GpsRequiredEmptyState` appears with "Activa el GPS" copy.
- Re-enable device GPS.
- `gpsStatusProvider` emits `ready` → UI auto-resolves (no navigation required), map screen returns.

---

## Scenario F — RTDB security: vendor A cannot write to vendor B's node

**Steps:**
1. Authenticate as Vendor A in emulator.
2. Attempt to write directly to `/vendedores_activos/uid-B` (e.g., using Firebase REST API with Vendor A's token).

**Expected:**
- Write is rejected with `403 Permission denied`.
- `/vendedores_activos/uid-B` remains unchanged.

---

## Scenario G — Ghost vendor cleaned up on crash (onDisconnect)

**Steps:**
1. Vendor A starts transmission (node appears in RTDB).
2. Force-kill the Flutter app process (simulate crash) without calling `stopTransmission`.
3. Wait ~10 seconds.

**Expected:**
- `/vendedores_activos/uid-A` node is automatically removed by Firebase's `onDisconnect().remove()` handler.

---

## Pass criteria

All 7 scenarios must pass. Record results in the PR description with emulator session ID.
