# Bike Taxi native build plugin

Android-only FFI plugin for `../rust`, generated from the official Flutter Rust
Bridge 2.11.1 Cargokit template. Flutter/Gradle compiles and bundles the requested
Android ABIs. No precompiled application binaries are checked in.

`cargokit/` is vendored upstream build tooling; its LICENSE is retained. Keep
upgrades separate from application logic. See `../docs/flutter-rust-poc.md` for
setup, validation, limitations and rollback.
