# GT7 Packet C Protocol

## surfaceType-based off-track detection

**Field:** `surfaceType[4]` at offset `0x158` (decimal 344), 4 raw ASCII bytes.

Wheel order: FL, FR, RL, RR.

### Known values

| Char | Surface     |
|------|-------------|
| `T`  | Tarmac      |
| `C`  | Curb        |
| `D`  | Dirt        |
| `G`  | Grass       |
| `S`  | Sand        |
| `s`  | Snow        |

### Heuristic: `isOnTrack`

1. If all 4 wheel values are known (one of `T`, `C`, `D`, `G`, `S`, `s`):
   - Count off-track surfaces: `D`, `G`, `S`, `s`.
   - `isOnTrack = true` when **fewer than 3** wheels are on off-track surfaces.
   - `isOnTrack = false` when **3 or more** wheels are on off-track surfaces.
2. If any wheel value is unknown/malformed → fallback to `simulatorFlags` bit 0 (`Car On Track`).

### Derivation source

Implemented in `Gt7Packet.isOnTrack` (`lib/core/telemetry/gt7/gt7_packet.dart`).
