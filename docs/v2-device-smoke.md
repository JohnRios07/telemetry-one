# V2 Device Smoke Test

Verify the full device-to-backend lifecycle: start recording → backend session created → frame batches use `session_*` → stop recording → backend finish called.

## Prerequisites

- Flutter SDK (same version as `pubspec.yaml` SDK constraint)
- GT7 on PS5 with telemetry enabled, **or** a telemetry simulator
- Backend testing instance at `http://129.213.127.143:8081` (Postgres, session lifecycle verified)

## Step 1 — Verify backend health

```bash
curl -s http://129.213.127.143:8081/health | jq .
```

Expected:
```json
{"status":"UP"}
```

If the backend is unreachable, check Postgres containers and restart via docker-compose.

## Step 2 — Run Flutter with testing config

```bash
flutter run \
  --dart-define=backend_base_url=http://129.213.127.143:8081 \
  --dart-define=use_v2_data=true
```

What this does:
- `backend_base_url` — overrides the default `http://localhost:8080` with the testing backend
- `use_v2_data=true` — enables V2 data mode: on `setEnabled(true)`, the sync notifier calls `POST /api/v1/sessions` to create a backend-owned session
- Both defines are read at compile time by `createBackendConfigFromEnv()` in `lib/core/backend/backend_sync_provider.dart`
- **If not provided**: defaults are `http://localhost:8080` and `useV2Data=false` — production V1 behavior is unchanged

### Shortcut with alias

Add to `~/.zshrc` or `~/.bashrc`:

```bash
alias flutter-v2-smoke='flutter run --dart-define=backend_base_url=http://129.213.127.143:8081 --dart-define=use_v2_data=true'
```

Then:

```bash
flutter-v2-smoke
```

## Step 3 — Start recording

1. Ensure PS5 is on with GT7 running, or telemetry simulator is sending data
2. In the app, connect to the PS5 IP
3. Enable backend sync: tap the power icon (⏻) in the **V2 sync badge** located in the HeaderBar next to the RECORD/STOP button
   - Badge shows: status dot + label (OFF/IDLE/SYNC/DOWN/REJ/FAIL)
   - When enabled, the badge expands to show the effective session ID and frame counters (P: pending, S: sent, A: accepted, R: rejected)
   - When R is non-zero, the top rejection reason code appears next to R (e.g. `R:2 invalid_throttle`)
   - The rejection code clears on the next successful flush with no rejections
4. **Check Flutter console logs** for:
   - `[BackendSync] Backend session created: session_*`
   - Frame batches posted to the backend

Expected evidence in Flutter console:

```
[BackendSync] Backend session created: session_abc123
[BackendSync] Flushed 120 frames — accepted: 120, rejected: 0
```

**On-device evidence** (no console needed):
- V2 sync badge shows status: `IDLE` (green) or `SYNC` (cyan)
- Badge displays `session_abc12…` confirming backend session alignment
- Counters increment as frames are sent/accepted

## Step 4 — Verify session_* on backend

While recording, query the testing backend:

```bash
# List active sessions (if endpoint exists)
curl -s http://129.213.127.143:8081/api/v1/sessions | jq .
# Or check session frames
curl -s http://129.213.127.143:8081/api/v1/sessions/session_abc123/frames | jq '. | length'
```

The session ID should start with `session_` (not `local_`), confirming backend session alignment succeeded.

## Step 5 — Stop recording

1. Disable backend sync: tap the power icon (⏻) in the **V2 sync badge** again
   - Badge returns to `OFF` (dim) state
   - Session ID and counters disappear from the badge
2. **Check Flutter console logs** for:
   - `[BackendSync] Finished backend session: session_abc123`

Expected evidence in Flutter console:

```
[BackendSync] Finished backend session: session_abc123
```

## Step 6 — Verify Finish on backend

```bash
# Check session status
curl -s http://129.213.127.143:8081/api/v1/sessions/session_abc123 | jq '.status'
```

Expected: `"finished"`

Verify Postgres containers are healthy:

```bash
docker ps --filter name=postgres
```

## Step 7 — Fallback test (V1 safety)

Run without V2 defines to confirm local-only behavior still works:

```bash
flutter run
```

- Start recording without V2
- Verify session ID is `local_*`
- Verify no backend calls (no `POST /api/v1/sessions`)
- Verify all telemetry and recording work as before

## Step 8 — Rollback test (backend failure)

Simulate a backend failure by stopping the backend or providing an unreachable URL:

```bash
flutter run \
  --dart-define=backend_base_url=http://localhost:1 \
  --dart-define=use_v2_data=true
```

Expected:
- Session alignment attempts → fails with `alignmentStatus: failed`
- Sync continues with `local_*` session ID (fallback)
- Frame batches use `local_*` ID
- V2 sync badge shows `DOWN` (yellow dot)
- Counters show frame accumulation in buffer
- When backend recovers, badge returns to `IDLE` (green dot)

## Commands reference

| Action | Command |
|--------|---------|
| Run with testing backend | `flutter run --dart-define=backend_base_url=http://129.213.127.143:8081 --dart-define=use_v2_data=true` |
| Run with custom driver alias | `flutter run --dart-define=backend_base_url=http://129.213.127.143:8081 --dart-define=use_v2_data=true` (alias is `backend_driver_alias` TODO) |
| Run V1 default | `flutter run` |
| Build APK testing | `flutter build apk --dart-define=backend_base_url=http://129.213.127.143:8081 --dart-define=use_v2_data=true` |
| Build IPA testing | `flutter build ios --dart-define=backend_base_url=http://129.213.127.143:8081 --dart-define=use_v2_data=true` |
| Run config tests | `flutter test test/backend/backend_config_provider_test.dart` |

## Config provider anatomy

```
lib/core/backend/backend_sync_provider.dart
├── createBackendConfigFromEnv()  ← reads --dart-define, falls back to defaults
└── backendConfigProvider         ← Riverpod provider using env config
```

## What to check on device

1. **Is telemetry arriving?** Dashboard shows live data (speed, RPM, gear)
2. **Is sync enabled?** V2 sync badge in HeaderBar shows status dot + label; counters increment
3. **Session ID format** — badge shows `session_abc12…` (shortened) or check Flutter console for full ID
4. **Accepted vs rejected frames** — badge shows `P:0 S:5 A:5 R:0` counters; non-zero A, zero or low R. When R is non-zero, the rejection code (e.g. `invalid_throttle`) appears next to the R count — inspect to understand why frames are being rejected
5. **Finish called on stop** — tap power icon to disable; console shows `Finished backend session`
6. **Postgres healthy** — containers running, session data persisted

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| `backend_base_url` typo | Sync to wrong/dead URL → degraded | Check logs for `backend_base_url` value |
| GT7 not sending data | Zero frames, sync idle | Verify PS5 UDP output and IP config |
| Backend schema mismatch | Frame rejection | Check `lastRejection` in state, backend logs |
| V2 data on production build | Unexpected backend dependency | Only activates with `--dart-define=use_v2_data=true`; default is `false` |
| Test backend credentials drift | Auth failures | Keep backend URL documented and verified in step 1 |

## Follow-ups

- [ ] Add `backend_driver_alias` dart-define for per-developer session attribution
- [ ] Add CI smoke step that runs flutter test with dart-define set
- [ ] Consider `--dart-define-from-file` for teams sharing config
