# Incremental Flutter/Rust POC

Rust is opt-in on Android. The default customer/driver behavior and Flutter Web
admin use Dart. No UI, authentication, Firestore rules/schema/state transitions,
Valhalla request semantics, driver sorting or earnings logic were changed.

## Architecture

`common.dart` re-exports `fareFor`; `routing.dart` re-exports `decodePolyline`.
Both signatures and all UI call sites remain unchanged. `compute.dart` selects
Dart or Rust. `main()` initializes compute before Firebase initialization.

- `compute_dart.dart`: original double-fare formula and a checked polyline decoder.
- `compute_native.dart`: initializes FRB only on Android with `USE_RUST=true`.
  Initialization failure logs a diagnostic and leaves Dart selected. Invalid
  computation inputs remain errors; they are not silently retried with another backend.
- `compute_rust.dart`: converts flat `Float64List` pairs into the existing
  `List<LatLng>`, and Rust string errors into Dart `FormatException`.
- `compute_stub.dart`: Web implementation; conditional imports exclude the
  native adapter. No Rust/WASM asset or Rust initialization is needed for Web.
- `rust/src/api/compute.rs`: pure Rust, no network/platform/Firestore access.
- `lib/src/rust/` and `rust/src/frb_generated.rs`: generated FRB bindings.
- `rust_builder/`: Android FFI plugin and vendored Cargokit from the official
  FRB **2.11.1** integration template. This is supported Cargo/Gradle integration,
  not a custom JNI build or a checked-in binary. Android flavors are inherited
  from the existing app. Other native platforms are outside this POC.

FRB Dart runtime, Rust dependency and generator are pinned to **2.11.1**. This
version was verified against the repository's Flutter 3.38.3 / Dart 3.10.1.
Cargokit builds and bundles all requested Android ABIs even when Dart is selected;
the runtime flag is a computation rollback, not a native packaging rollback.
The vendored Cargokit files retain their upstream license.

References: [FRB integration](https://cjycode.com/flutter_rust_bridge/manual/integrate/builtin),
[Cargokit](https://cjycode.com/flutter_rust_bridge/manual/integrate/cargokit),
[FRB 2.11.1](https://pub.dev/packages/flutter_rust_bridge/versions/2.11.1).

## Contracts and trust

Polyline precision defaults to 6 (Valhalla); precision 5 is also supported.
Empty input returns an empty list. Duplicates and negative deltas are preserved.
Invalid precision, non-ASCII/out-of-alphabet bytes, truncation, components longer
than six groups and coordinates beyond ±90/±180 fail deterministically. Both
backends throw matching `FormatException` messages. Valid coordinates match the
original decoder exactly. The original had unchecked reads and no validation;
malformed-input exception types are intentionally made consistent in this POC.
Browser testing also exposed the original decoder's signed `~` reconstruction:
Dart-to-JavaScript uses unsigned bitwise results. The fallback now uses
`-(value >> 1) - 1` for negative deltas. This preserves native coordinates and
fixes browser coordinates, covered by the original Google vector and all six
captured route fixtures. This is the only additional behavior correction.

Fare retains the exact left-associated double operations:

```dart
((2.5 + 1.5 * km * 0.621371) * 10).round() / 10
```

Rust uses half-away-from-zero rounding and Dart-native signed-64-bit integer
saturation before converting back to double. Non-finite inputs or intermediate
prices are rejected, as with Dart's previous `round()`. No integer-cents schema
or decimal arithmetic replacement was introduced. Distances remain kilometers;
Firestore fare remains a double. Tests check the existing formula's $0.06 rule
tolerance; the rules themselves are unchanged.

**Client Rust is not trusted fare enforcement.** Clients can change their code.
The existing rules bound distance and check a formula but do not independently
prove a Valhalla route. Production enforcement still needs trusted server-side
routing and fare calculation. This POC neither replaces nor weakens that need.

Calls remain synchronous to preserve existing map/build and fare APIs. Large
routes still block the UI isolate during calls, including FFI and conversion.
This POC makes no claim about frame rates or battery life. See measured results
and workload limitations in [benchmarks](flutter-rust-benchmarks.md).

## Setup, generation and builds

Install Flutter 3.38.3, a Rust toolchain with `cargo`/`rustup` on PATH, Java 21 and
an Android SDK with accepted licenses and the NDK requested by Flutter
(28.2.13676358 in the validation environment). Cargokit installs the Rust Android
targets it needs. Initial builds require network access for dependencies.

```sh
flutter pub get
cargo install flutter_rust_bridge_codegen --version 2.11.1 --locked
# Also requires cargo-expand; the generator can install it automatically.
flutter_rust_bridge_codegen generate
dart format lib/src/rust
# Codegen config disables whole-app Dart fixes/formatting; only bindings are formatted.

flutter build apk --flavor customer --dart-define=USE_RUST=true
flutter build apk --flavor driver --dart-define=USE_RUST=true
flutter build web

# Default Dart; explicit false also works.
flutter run --flavor customer --dart-define=USE_RUST=false
flutter run --flavor driver --dart-define=USE_RUST=true
# Existing EMULATOR_HOST and VALHALLA_URL definitions work as before.
```

Do not run Flutter build/test/pub commands concurrently in one checkout: Flutter
rewrites shared generated plugin registration files.

## Tests

```sh
./tool/verify_compute.sh
# Host parity tests load rust/target/release's actual dynamic library, not mocks.

# Browser tests prove the Web fallback even if the Rust flag is supplied.
flutter test --platform chrome --dart-define=USE_RUST=true \
  test/polyline_test.dart test/compute_fallback_test.dart

# Android packaged-library parity + mocked HTTP contract, no Firebase account needed.
flutter test integration_test/compute_test.dart -d emulator-5554 \
  --flavor customer --dart-define=USE_RUST=true
flutter test integration_test/compute_test.dart -d emulator-5554 \
  --flavor driver --dart-define=USE_RUST=true
# Repeat with USE_RUST=false to exercise the production Dart dispatcher.

(cd rules-test && npm ci)
JAVA_HOME=/Library/Java/JavaVirtualMachines/temurin-21.jdk/Contents/Home \
  firebase emulators:exec --only firestore --project demo-bike-taxi 'node --test rules-test/'
```

The contract suite compares the real Rust library against the original Dart
polyline decoder, captured precision 5/6 fixtures, 1,004 generated coordinate
points including poles/dateline, invalid input, more than 10,000 fare samples
and rounding thresholds. Rust unit tests also exhaust all 16,384 two-byte ASCII
inputs to check that decoding does not panic. Device tests verify the selected
backend, existing Valhalla POST payload, response decoding, stored-route replay,
fare numeric type and rules tolerance. HTTP is mocked to keep tests deterministic.
They do not test real OTP/login, a live routing server or a full live ride lifecycle.
The existing nine Firestore emulator rules tests remain separate.

`test/fixtures/compute.json` captures public Valhalla/OSM routes and synthetic
driver/trip data. `compute_fixture.dart` embeds that JSON for device tests without
adding production assets; regenerate it with `python3 tool/update_fixture_dart.py`.

## Rollback and known limits

- Immediate computation rollback: omit `USE_RUST` or rebuild with `USE_RUST=false`.
  Existing Firestore documents remain readable by both versions; no migration.
- Full packaging rollback: revert the POC commits in reverse order, then run
  `flutter clean && flutter pub get`. This removes the native plugin/dependencies.
- Android release APKs still use the repository's existing debug signing config.
  This POC does not change signing or publish an app.
- `PRODUCT.md` says straight-line fares/no road routing; the current README and
  implementation already use Valhalla. This pre-existing documentation mismatch
  is recorded here and left outside the POC.
- Existing plugin compilation emits Java/Kotlin metadata/deprecation diagnostics;
  final build exit status and runtime tests are recorded in the validation report.
- No physical Android device measurements, native sanitizers, startup/size delta
  comparison against the base branch, frame-time study or server fare enforcement.

Validation evidence: [commands, results and known limits](flutter-rust-validation.md).
