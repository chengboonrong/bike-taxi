# Flutter/Rust POC plan

Base: `7f30e60aa621f94feb3a30f972536a4c93673e0c`, branch `poc/flutter-rust-bridge`.

## Inspection

Read README.md, PRODUCT.md, pubspec.yaml, common.dart, routing.dart,
customer.dart, driver.dart, main.dart, test/polyline_test.dart, Android Gradle
configuration and firestore.rules. No CodeGraph index is present.

- Existing tests (one polyline test) and flutter analyze pass on Flutter 3.38.3 / Dart 3.10.1.
- Fare uses left-associated double operations: `((2.5 + 1.5 * km * 0.621371) * 10).round() / 10`.
- Customer computes fare for display and writes the same double to Firestore.
  Driver reads stored fares; earnings and nearest-pickup sorting stay in Dart.
- Decoder is synchronous, default precision 6; maps use it in widget builds.
  Preserve signatures to avoid restructuring UI or ride flows.
- Rules check formula within $0.06 and bound distance; they do not prove road
  distance. Rust does not strengthen this trust boundary. Trusted server-side
  routing/fare enforcement remains necessary for production.
- PRODUCT.md still says straight-line pricing and no road routes. README and
  implementation use Valhalla. Record this discrepancy; do not rewrite product scope.
- Existing decoder has no malformed-input checks. Define matching Dart/Rust
  errors for truncated, invalid, oversized and out-of-range coordinates.

## Incremental commits

1. This plan and baseline evidence.
2. Embedded Rust crate, pinned FRB codegen/runtime, supported Cargokit native
   plugin, generated bindings, Dart fallback and opt-in Android dispatcher.
3. Shared realistic synthetic NYC route/driver fixtures, Rust tests, Dart parity
   and integration checks, benchmarks including bridge/conversion costs.
4. Architecture, measured results, reproducible commands, rollback and draft PR.

## Success criteria

- Exact coordinate and double-fare parity for precision 5/6, realistic routes,
  repeat calls, rounding boundaries and all finite supported ride distances.
- Malformed inputs fail deterministically without Rust panics.
- Android uses Rust only with `--dart-define=USE_RUST=true`; default remains Dart.
  Web always uses Dart and needs no WASM/Rust initialization.
- Firebase auth, Firestore schema/rules/state transitions, HTTP request semantics,
  Android flavors, and UI remain unchanged.
- Rust tests, generated-binding Dart parity tests and native integration checks
  pass; both customer/driver APKs and Web admin compile. Record any blocked checks.
- Benchmarks use identical data and output consumption, warmup and repeated
  samples. Report environment and raw results; no unmeasured speedup claims.
