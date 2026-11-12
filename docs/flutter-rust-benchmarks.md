# Flutter/Rust benchmark results

Measured 2026-11-12, computation source commit `544e4cb`. **No end-to-end
performance improvement was observed in these workloads.** Rust was slower than
the checked Dart fallback in every recorded median on both environments. Keep
Dart selected by default. These measurements prove a working bridge and its
costs on this setup; they do not justify enabling Rust for performance.

## Environment and method

- Host: Apple M1 Max, arm64, macOS 27.0 (26A428), Flutter 3.38.3 / Dart 3.10.1.
  Dart compiled with `dart compile exe` (AOT), Rust with Cargo `--release`.
- Android: Pixel_9a AVD, `sdk_gphone64_arm64`, Android 17 / API 37, emulator
  37.2.12.0, hosted on the same Mac. Flutter **profile mode (AOT)**, Rust
  `--release` via Cargokit. Java 21.0.8, NDK 28.2.13676358, Rust 1.99.1,
  FRB runtime/codegen 2.11.1.
- Flutter 3.38's driver rejects `--release`; its supported `--profile` mode was
  used for Android measurement. This is not a physical-device/release-mode result.
- `tool/compute_benchmark.dart` runs identical inputs through the checked Dart
  fallback and the actual generated FRB/native library plus adapter. JSON parsing
  and initialization occur before timing. Each route result is fully consumed
  into a checksum; fares are also consumed. Backend checksums must match.
- Batch sizes double until either backend takes at least 20 ms or the cap of
  65,536 iterations is reached. Both use that same iteration count. There are
  five warmup batches, then 15 measured batches per backend with alternating
  Dart/Rust order. Calibration precedes warmup, so final warm batch durations
  can be shorter than the calibration threshold. Counts are in the raw files.
- Stopwatch microseconds are divided by batch iterations. Tables report median
  and nearest-rank p95 **of the 15 batch means**, not individual-call p95 latency.
  Microsecond timer granularity is amortized; very small fare timings should be
  interpreted as microbenchmark estimates, not application latency promises.
- Rust measurements include string serialization, FFI/native execution, result
  transfer, conversion to `List<LatLng>` and output consumption. Dart includes its
  matching validation, coordinate allocation and consumption. Dispatcher flag
  checks, startup, HTTP, Firebase and widget rendering are excluded.
- Dart baseline is the POC's checked fallback, including the browser sign fix.
  The original unchecked decoder is used as a native correctness oracle, not
  timed separately. Rust kernel-only time was not measured.
- One process/run per environment; no CPU pinning, thermal/frequency control,
  GC forcing or confidence intervals. No concurrent build/test workload was run
  during either final measurement. The two environments share host hardware;
  they are not independent physical-device samples.

## Data

`test/fixtures/compute.json` contains three actual motorcycle routes from the
public FOSSGIS Valhalla server captured on 2026-11-12 (map data © OpenStreetMap
contributors, ODbL). Requests used kilometers, `search_cutoff: 300` and
`directions_type: none`, matching the app's payload. Public server responses may
change; tests and timings replay the checked-in data without network access.

| Route | Requested endpoints (lat, lon) | Road km | Points |
| --- | --- | ---: | ---: |
| Midtown | (40.7549, -73.9840) → (40.7506, -73.9935) | 1.472 | 70 |
| Central Park | (40.7580, -73.9855) → (40.7851, -73.9683) | 6.833 | 352 |
| Brooklyn–Manhattan | (40.6782, -73.9442) → (40.7549, -73.9840) | 15.698 | 549 |

The server returns precision 6. Precision-5 variants are derived offline by
quantizing those coordinates and encoding them again; they are not additional
server responses. A JFK endpoint was rejected during capture and was replaced
with Brooklyn; this did not require any application API change.

100 synthetic driver/trip records have IDs, positions sampled from the routes,
route assignments, a started status and deterministic trip distances between
0.3 and 60 km. They contain no real drivers or personal data. The 100-update
workload replays a route decode for each record, modeling repeated driver map
refresh computation. It is a stress replay, not a fleet simulation or new
matching algorithm. The actual driver's sorting and stored-fare display remain
unchanged. The 100-fare workload is a sensitivity test over varied trip lengths,
not a claim that the driver app recalculates fares. The fixed single-fare test
can benefit from compiler optimization; prefer the varied batch for comparison.

## Android profile AOT, arm64 emulator

All values are microseconds per named workload. The final row is 100 decodes;
the two fare rows are one fare and 100 fares respectively.

| Workload | Dart median | Dart p95 | Rust median | Rust p95 | Rust / Dart median |
| --- | ---: | ---: | ---: | ---: | ---: |
| Decode Midtown, p6 (70 points) | 2.948 | 3.002 | 4.333 | 4.430 | 1.47× |
| Decode Central Park, p6 (352 points) | 14.066 | 14.537 | 17.521 | 21.317 | 1.25× |
| Decode Brooklyn, p6 (549 points) | 23.396 | 24.412 | 27.601 | 27.791 | 1.18× |
| Decode Midtown, p5 (70 points) | 2.874 | 3.078 | 3.977 | 4.032 | 1.38× |
| Decode Central Park, p5 (352 points) | 14.900 | 19.134 | 17.130 | 19.822 | 1.15× |
| Decode Brooklyn, p5 (549 points) | 22.646 | 25.487 | 24.631 | 27.104 | 1.09× |
| One fare, fixed 1.472 km | 0.010 | 0.016 | 0.318 | 0.341 | 33.14× |
| 100 synthetic driver/trip fares | 0.357 | 0.418 | 31.796 | 37.709 | 88.96× |
| 100 driver route updates | 1333.938 | 1379.688 | 1639.750 | 1735.500 | 1.23× |

Raw samples: [android-profile-arm64.json](benchmarks/android-profile-arm64.json).

## macOS AOT, arm64 host

| Workload | Dart median | Dart p95 | Rust median | Rust p95 | Rust / Dart median |
| --- | ---: | ---: | ---: | ---: | ---: |
| Decode Midtown, p6 (70 points) | 2.586 | 2.612 | 4.210 | 4.337 | 1.63× |
| Decode Central Park, p6 (352 points) | 12.155 | 12.589 | 15.708 | 16.363 | 1.29× |
| Decode Brooklyn, p6 (549 points) | 20.028 | 20.981 | 24.862 | 25.997 | 1.24× |
| Decode Midtown, p5 (70 points) | 2.354 | 2.370 | 3.796 | 3.841 | 1.61× |
| Decode Central Park, p5 (352 points) | 11.429 | 12.207 | 13.964 | 15.123 | 1.22× |
| Decode Brooklyn, p5 (549 points) | 18.795 | 19.041 | 21.827 | 21.935 | 1.16× |
| One fare, fixed 1.472 km | 0.007 | 0.008 | 0.259 | 0.260 | 34.84× |
| 100 synthetic driver/trip fares | 0.351 | 0.373 | 25.427 | 25.667 | 72.53× |
| 100 driver route updates | 1163.625 | 1170.750 | 1507.938 | 1535.688 | 1.30× |

Raw samples: [macos-aot-arm64.json](benchmarks/macos-aot-arm64.json).

The measured Rust path, including the bridge and coordinate conversion, costs
more than Dart for these workloads. Kernel-only time is unmeasured, so these
results do not isolate the cost of serialization, conversion or computation.
No claim is made about startup, APK size change, battery, UI frame time or
larger/other workloads.

## Reproduce

Use the setup in [architecture/build documentation](flutter-rust-poc.md).
Run Flutter commands sequentially in one checkout.

```sh
flutter pub get
cargo build --release --manifest-path rust/Cargo.toml --locked
mkdir -p build/benchmarks
dart compile exe tool/benchmark_compute.dart -o build/benchmark_compute
build/benchmark_compute > build/benchmarks/compute_macos_aot.json

flutter drive --driver=test_driver/benchmark.dart \
  --target=integration_test/benchmark_test.dart -d emulator-5554 \
  --profile --flavor customer --dart-define=USE_RUST=true
# Full device results: build/benchmarks/compute_android.json.
# The Android log line may truncate; use the driver's JSON output.
```

The benchmark harness deliberately performs synchronous loops and can log
skipped frames. That is harness blocking, not a frame-time comparison of the app.
Physical Android profiling, asynchronous decode API/UI changes, alternative
batching and native-only optimization are outside this POC.

Fixture SHA-256: `d8906393a16d0272adf49fe04cf816e610304ab685fb6790f45620d5d903b3c3`.
