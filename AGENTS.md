# Code Review Rules

## Flutter
- Prefer small, composable widgets with clear responsibilities.
- Keep UI state in Riverpod providers or widget-local state when appropriate.
- Avoid mutating provider state during widget build lifecycles.

## Dart
- Prefer explicit types at module boundaries.
- Keep derived values clearly separated from raw protocol fields.
- Do not invent telemetry data; document placeholders and derived fields explicitly.

## Telemetry / GT7
- Preserve protocol accuracy when mapping packet offsets.
- Keep packet parsing and UI presentation concerns separated.
- Prefer additive changes that maintain backward compatibility in the domain model.
