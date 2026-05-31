# TestFlight

When the user runs `/testflight`, push Content Calendar to TestFlight with automatic internal-tester notification (same flow as Mockups).

## Command

From the project root:

```bash
./scripts/build-ipa-for-testflight.sh --upload
```

This single script is the **canonical** TestFlight path. Do not use ad-hoc `flutter build ipa` or manual Transporter uploads unless debugging.

## Release guards (prevents shipping regressed local edits)

Before every build/upload, the script runs:

1. **`scripts/verify-release-readiness.py`** — required Voltis Core wiring present; forbidden regressions (custom photos, old paywall-only Plans) absent; pubspec build number matches `ios/Flutter/Generated.xcconfig`
2. **`test/release_integrity_test.dart`** — same rules via `flutter test`

For **`--upload` only**: fails if release-critical files have **uncommitted git changes** unless `ALLOW_DIRTY_RELEASE=1` is set. **Commit first**, then upload.

Install optional pre-commit hook (blocks bad commits to critical files):

```bash
./scripts/install-release-guard-hooks.sh
```

## What the script does

1. **Verify** — release readiness + integrity test
2. **Build** — sync iOS config from pubspec, archive, export iPhone-only IPA
3. **Upload** — `xcrun altool --upload-package` (credentials in `scripts/testflight-credentials.json`, gitignored)
4. **Auto-distribute** (optional) — assigns Internal Testing if API key configured; upload alone works like Mockups

## Version bump

Increment the build number in `pubspec.yaml` (`version: x.y.z+NN`) before each TestFlight upload. The script runs `flutter build ios --config-only` so the IPA matches pubspec.

## Monitoring (required)

- Stream output until **UPLOAD SUCCEEDED**
- Upload log: `/tmp/testflight_upload_contentcalendar.log`
- Processing on device: usually 5–15 minutes

## Report

- Confirm upload success and version/build numbers from script output
- Confirm release readiness passed
- Note App Store Connect processing time
