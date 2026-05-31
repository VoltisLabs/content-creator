#!/usr/bin/env python3
"""Block TestFlight/App Store builds that regressed release-critical wiring."""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent

REQUIRED_SNIPPETS: dict[str, list[str]] = {
    "lib/main.dart": [
        "AuthGate",
        "VoltisCoreService",
        "AppSettingsScope",
    ],
    "lib/widgets/settings_sheet.dart": [
        "SettingsPlansPage",
        "SettingsAccountPage",
        "onOpenAccount",
        "Voltis Core Account",
    ],
    "lib/screens/auth_gate.dart": [
        "class AuthGate",
    ],
    "lib/widgets/settings_plans_page.dart": [
        "class SettingsPlansPage",
        "VoltisPlansService",
    ],
}

FORBIDDEN_SNIPPETS: dict[str, list[str]] = {
    "lib/main.dart": [
        "CustomBackgroundService",
        "initialUseCustomBackground",
    ],
    "lib/widgets/settings_sheet.dart": [
        "_SettingsBackgroundPage",
        "CustomBackgroundService",
        "PaywallSheetBody(embeddedInSettings",
        "_SettingsPaywallPage",
        "title: 'Background'",
        "Custom photo",
    ],
}

FORBIDDEN_FILES = [
    "lib/services/custom_background_service.dart",
]

CRITICAL_GIT_PATHS = [
    "lib/main.dart",
    "lib/widgets/settings_sheet.dart",
    "lib/widgets/settings_account_page.dart",
    "lib/widgets/settings_plans_page.dart",
    "lib/screens/auth_gate.dart",
    "lib/services/voltis_core_service.dart",
    "lib/state/app_settings.dart",
    "pubspec.yaml",
]


def read(rel: str) -> str:
    path = PROJECT_ROOT / rel
    if not path.is_file():
        raise FileNotFoundError(f"Missing required file: {rel}")
    return path.read_text(encoding="utf-8")


def check_required() -> list[str]:
    errors: list[str] = []
    for rel, snippets in REQUIRED_SNIPPETS.items():
        try:
            text = read(rel)
        except FileNotFoundError as error:
            errors.append(str(error))
            continue
        for snippet in snippets:
            if snippet not in text:
                errors.append(f"{rel}: missing required `{snippet}`")
    return errors


def check_forbidden() -> list[str]:
    errors: list[str] = []
    for rel in FORBIDDEN_FILES:
        if (PROJECT_ROOT / rel).exists():
            errors.append(f"Removed feature file still present: {rel}")
    for rel, snippets in FORBIDDEN_SNIPPETS.items():
        if not (PROJECT_ROOT / rel).is_file():
            continue
        text = read(rel)
        for snippet in snippets:
            if snippet in text:
                errors.append(f"{rel}: forbidden regression `{snippet}`")
    return errors


def pubspec_build_number() -> int | None:
    text = read("pubspec.yaml")
    match = re.search(r"^version:\s*[\d.]+\+(\d+)\s*$", text, re.MULTILINE)
    return int(match.group(1)) if match else None


def ios_generated_build_number() -> int | None:
    path = PROJECT_ROOT / "ios/Flutter/Generated.xcconfig"
    if not path.is_file():
        return None
    text = path.read_text(encoding="utf-8")
    match = re.search(r"^FLUTTER_BUILD_NUMBER=(\d+)\s*$", text, re.MULTILINE)
    return int(match.group(1)) if match else None


def check_version_sync() -> list[str]:
    errors: list[str] = []
    pubspec_build = pubspec_build_number()
    if pubspec_build is None:
        errors.append("pubspec.yaml: could not parse version: x.y.z+NN")
        return errors
    ios_build = ios_generated_build_number()
    if ios_build is None:
        errors.append(
            "ios/Flutter/Generated.xcconfig missing — run "
            "`flutter build ios --config-only` before archiving."
        )
        return errors
    if pubspec_build != ios_build:
        errors.append(
            f"Build number mismatch: pubspec +{pubspec_build} vs "
            f"ios Generated.xcconfig {ios_build}. "
            "Run `flutter build ios --config-only`."
        )
    return errors


def git_dirty_critical_paths() -> list[str]:
    proc = subprocess.run(
        ["git", "status", "--porcelain", "--", *CRITICAL_GIT_PATHS],
        cwd=PROJECT_ROOT,
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0:
        return [f"git status failed: {proc.stderr.strip()}"]
    lines = [line for line in proc.stdout.splitlines() if line.strip()]
    return lines


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--upload",
        action="store_true",
        help="Stricter checks before uploading to App Store Connect.",
    )
    args = parser.parse_args()

    errors = check_required() + check_forbidden() + check_version_sync()

    if args.upload:
        dirty = git_dirty_critical_paths()
        if dirty:
            allow = __import__("os").environ.get("ALLOW_DIRTY_RELEASE") == "1"
            summary = "\n".join(f"  {line}" for line in dirty)
            if allow:
                print(
                    "⚠️  Uncommitted changes on release-critical files "
                    "(ALLOW_DIRTY_RELEASE=1):\n"
                    f"{summary}"
                )
            else:
                errors.append(
                    "Uncommitted changes on release-critical files. "
                    "Commit first, or set ALLOW_DIRTY_RELEASE=1 to override:\n"
                    f"{summary}"
                )

    if errors:
        print("❌ Release readiness check failed:", file=sys.stderr)
        for error in errors:
            print(f"   • {error}", file=sys.stderr)
        print(
            "\nFix the issues above before TestFlight upload. "
            "This prevents shipping an older/regressed build from local edits.",
            file=sys.stderr,
        )
        return 1

    build = pubspec_build_number()
    print(f"✅ Release readiness OK (build {build}).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
