#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="$HOME/flutter/bin:$PATH"
cd "${PROJECT_ROOT}"
flutter test test/release_integrity_test.dart
