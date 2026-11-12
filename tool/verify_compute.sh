#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
flutter pub get
cargo fmt --manifest-path rust/Cargo.toml --check
cargo test --manifest-path rust/Cargo.toml --locked
cargo build --release --manifest-path rust/Cargo.toml --locked
flutter analyze --no-pub
flutter test --no-pub
