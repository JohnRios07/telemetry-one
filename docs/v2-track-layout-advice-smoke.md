# V2 Track/Layout + Race Engineer Advice Smoke

Device-only smoke for backend PRs #26-#29 and Flutter PR #18.

This is a manual validation step, not a merge gate. If the device or backend is unavailable, record the failure and continue.

## Prerequisites

- PS5 running GT7 with telemetry enabled
- Tablet/device running the Flutter app
- Backend reachable at `http://129.213.127.143:8081`
- A session that can collect enough frames to complete lap 1
- OpenRouter configured only if you want to verify real-provider advice handling

## Flutter Run

```bash
flutter run \
  --dart-define=backend_base_url=http://129.213.127.143:8081 \
  --dart-define=use_v2_data=true
```

## Smoke Sequence

1. Verify backend health:

```bash
curl -s http://129.213.127.143:8081/health | jq .
```

Expected: `{"status":"UP"}`.

2. Start the app, connect to the PS5, and begin a session.

Expected initial UI state:
- HeaderBar Track/Layout shows `unknown` or `detecting`
- Lap 1 starts before detection completes
- This is expected until enough data exists

3. Confirm track detection is still pending before the first completed lap:

```bash
curl -s http://129.213.127.143:8081/api/v1/sessions/$SESSION_ID/track | jq '{status, reason: .reasons[0], nextAction, trackId, layoutId}'
```

Expected: `status: "pending"` with a reason like `insufficient_data` or `no_completed_lap`.

4. Complete lap 1.

Expected after completion:
- Track detection transitions to `detected`
- HeaderBar Track/Layout updates to the detected track/layout
- Session summary or session listing includes non-null `detectedTrackId` and `detectedLayoutId`

```bash
curl -s http://129.213.127.143:8081/api/v1/sessions/$SESSION_ID/track | jq '{status, trackId, layoutId, trackName, layoutName, nextAction}'
curl -s http://129.213.127.143:8081/api/v1/sessions/$SESSION_ID/summary | jq '.session | {detectedTrackId, detectedLayoutId, trackId, status}'
```

5. Verify engineer events carry track/layout refs:

```bash
curl -s "http://129.213.127.143:8081/api/v1/sessions/$SESSION_ID/events?lapNumber=1" | jq '.events[] | {type, lapNumber, track, layout}'
```

Expected:
- Events include `track` and `layout` refs once detection has settled
- Catalog names come from backend catalog metadata, not GT7 UDP

6. Verify advice uses persisted session refs:

```bash
curl -s -X POST http://129.213.127.143:8081/api/v1/sessions/$SESSION_ID/race-engineer/advice \
  -H 'Content-Type: application/json' \
  -d '{"maxEvents":5}' | jq '{sessionId, status, message, advice, referencedEvents, window, providerInfo}'
```

Expected:
- Advice succeeds when there are stored engineer events
- Response includes `sessionId`, `status`, `message` or `advice`, `referencedEvents`, `window`, and `providerInfo`
- If a selected event window is missing track/layout refs, the backend still uses `detectedTrackId` and `detectedLayoutId` from the session
- `referencedEvents` identifies the stored events that informed the advice

7. Verify real-provider handling only when OpenRouter is enabled:

- Success path: `status: "success"` and provider metadata is reflected in `providerInfo` when available
- Rate limit path: `status: "rate_limited"`
- Provider failure path: `status: "provider_error"` with safe fallback text
- Do not expect `budget_limited` or `invalid_response` from the current contract

## Failure Triage

| Symptom | Likely cause | Check |
| --- | --- | --- |
| Health check fails | Backend down or wrong URL | `curl /health`, confirm `http://129.213.127.143:8081` |
| Track stays `pending` after lap 1 | Not enough retained frames or lap not actually completed | Re-check `/track` reason and keep driving |
| `detectedTrackId` / `detectedLayoutId` remain null | Detection did not persist | Confirm the completed lap was observed and session summary updated |
| Events have null refs | Events were emitted before detection settled | Re-run `/events?lapNumber=1` after detection |
| Advice returns `no_events` | No stored engineer events in the selected window | Not a transport failure; drive more or widen `sinceUnixMs` |
| Advice returns `rate_limited` | OpenRouter throttled the request | Retry later; do not treat as a device failure |
| Advice returns `provider_error` | Provider/config issue | Check backend OpenRouter config and logs |

## Notes

- The smoke is only complete when the detected session refs, event refs, and advice output all agree on the same track/layout context.
- Do not block on this test if a device-required dependency is missing; capture the failure and continue.
