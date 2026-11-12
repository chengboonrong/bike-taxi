# POC validation evidence

Validated locally on 2026-11-12 against base `7f30e60`, computation/test commits
through `544e4cb`. Branch: `poc/flutter-rust-bridge`. Main remains at the base.
Environment: Flutter 3.38.3, Dart 3.10.1, Rust 1.99.1, FRB 2.11.1, Apple M1 Max
macOS 27.0, Java 21.0.8, Android compile SDK 36 / NDK 28.2.13676358.
Android runtime: Pixel_9a arm64 AVD, Android 17 / API 37.

## Automated checks

| Check | Result |
| --- | --- |
| `cargo fmt --manifest-path rust/Cargo.toml --check` | PASS |
| `cargo test --manifest-path rust/Cargo.toml --locked` | PASS, 4 unit tests (including 16,384 short malformed-input candidates) |
| `cargo clippy --manifest-path rust/Cargo.toml --all-targets --locked -- -D warnings` | PASS |
| `flutter analyze --no-pub` | PASS, no issues |
| `flutter test --no-pub` | PASS, 8 tests, actual host release Rust library |
| Chrome: `test/polyline_test.dart test/compute_fallback_test.dart`, `USE_RUST=true` | PASS, 3 tests; Web stays Dart |
| Android customer, `USE_RUST=true` | PASS, 5 integration/contract tests |
| Android driver, `USE_RUST=true` | PASS, 5 integration/contract tests |
| Android customer, `USE_RUST=false` | PASS, 5 integration/contract tests; repeated after browser correction |
| Android driver, `USE_RUST=false` | PASS, 5 integration/contract tests |
| Existing Firestore emulator suite, demo-bike-taxi | PASS, 9 rules tests |
| FRB 2.11.1 generation, followed by `dart format lib/src/rust` | PASS, generated bindings byte-identical to committed files |
| Android profile/AOT benchmark via packaged Cargokit library | PASS; full results saved through integration driver |
| macOS standalone Dart AOT benchmark + Rust release library | PASS |

The fare contract compares 15,870 finite distances (including 10,000 seeded
random values, 100 synthetic driver/trip values and both sides of positive and
negative rounding thresholds) and checks four non-finite/overflow cases. Route
parity compares every coordinate of six captured/derived route fixtures and
1,004 generated/extreme coordinates at each precision. See
[contracts and commands](flutter-rust-poc.md) and
[benchmark methodology, medians, p95 and raw samples](flutter-rust-benchmarks.md).

## Release builds

All use the existing flavors, package IDs, signing setup and main entrypoint.

| Command | Result |
| --- | --- |
| `flutter build apk --flavor customer --dart-define=USE_RUST=true` | PASS, 55.0 MB as reported by Flutter |
| `flutter build apk --flavor driver --dart-define=USE_RUST=true` | PASS, 55.3 MB |
| `flutter build apk --flavor customer --dart-define=USE_RUST=false` | PASS, 54.9 MB |
| `flutter build apk --flavor driver --dart-define=USE_RUST=false` | PASS, 55.1 MB |
| `flutter build web` | PASS |
| Earlier `flutter build web --dart-define=USE_RUST=true` | PASS; browser tests also verify this flag cannot select Rust on Web |

ZIP inspection confirms both final APKs contain `librust_lib_bike_taxi.so` for
`arm64-v8a`, `armeabi-v7a` and `x86_64`. Runtime tests exercise arm64 only.
`aapt dump badging` confirms the package IDs remain
`com.biketaxi.bike_taxi.customer` and `com.biketaxi.bike_taxi.driver`.
These APK sizes are absolute outputs, not size regressions measured against the
base branch. Final local APKs use `USE_RUST=false` and remain ignored build files.

| Final Dart-mode artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| app-customer-release.apk | 54926356 | `4b8c918bba00eba960069f1b537251a7cb706c1182b4e87151663d1e86b6c395` |
| app-driver-release.apk | 55090516 | `3a624b5ecc941600cacaa79374a3c13112375c1fa21a052512f285c9d1a4d7a8` |

## Observed issues and limits

- Browser validation exposed the original decoder's unsigned JavaScript bitwise
  NOT behavior for negative deltas. The POC replaces it with equivalent signed
  arithmetic, preserving native parity and correcting Web. Regression tests pass.
- Concurrent Flutter build/pub/test commands can leave generated registration
  files inconsistent. One initial driver build failed on the integration-test
  plugin registration during concurrent work. Sequential reruns and every final
  release build passed. No Gradle/dependency workaround was added.
- Flutter's integration cleanup sometimes attempted to uninstall the unflavored
  `com.biketaxi.bike_taxi` package and logged `DELETE_FAILED_INTERNAL_ERROR`.
  Flavored package runtime assertions and test commands exited successfully.
- The first customer build emitted Kotlin metadata version diagnostics (2.4.0
  versus expected 2.2.0) despite succeeding; Java/deprecation/plugin warnings also
  appeared. Final repeated builds passed. Android/Kotlin/Firebase configuration
  was left unchanged; no wider dependency upgrade was attempted.
- Flutter driver rejected release-mode benchmarking; Android results use its
  supported profile AOT mode with Rust release compilation. Synchronous benchmark
  loops log skipped frames; this is not an app frame-time measurement.
- Public Valhalla rejected a JFK capture endpoint; the long fixture uses Brooklyn.
  Tests and benchmarks require no live routing service.
- `PRODUCT.md` already disagrees with README/code about road routing. Documented,
  left outside the POC.
- No physical Android device measurements, full live OTP/ride lifecycle test,
  native sanitizers, server-side fare enforcement or baseline APK size comparison.
  HTTP integration is mocked; Firestore rules were tested separately and unchanged.

A diff against the base confirms no edits to customer.dart, driver.dart,
admin.dart, theme.dart, firestore.rules, Firebase configuration or Android flavor
configuration. Only compute exports and initialization connect the POC to the
existing app. No app was deployed and no main-branch changes were made.
