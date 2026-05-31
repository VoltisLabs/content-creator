#!/usr/bin/env python3
"""Assign a processed build to TestFlight beta groups via App Store Connect API."""

from __future__ import annotations

import argparse
import json
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

try:
    import jwt
except ImportError as exc:  # pragma: no cover
    raise SystemExit(
        "PyJWT is required. Install with: python3 -m pip install PyJWT cryptography"
    ) from exc

API_BASE = "https://api.appstoreconnect.apple.com/v1"


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def make_token(key_id: str, issuer_id: str, private_key: str) -> str:
    now = int(time.time())
    headers = {"alg": "ES256", "kid": key_id, "typ": "JWT"}
    payload = {"iss": issuer_id, "exp": now + 1200, "aud": "appstoreconnect-v1"}
    return jwt.encode(payload, private_key, algorithm="ES256", headers=headers)


def api_request(method: str, token: str, path: str, body: dict | None = None) -> dict:
    url = f"{API_BASE}{path}"
    data = None
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    }
    if body is not None:
        data = json.dumps(body).encode("utf-8")
    request = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            raw = response.read().decode("utf-8")
            if not raw:
                return {}
            return json.loads(raw)
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", errors="ignore")
        raise RuntimeError(f"{method} {path} failed ({error.code}): {detail}") from error


def find_build(token: str, app_id: str, version: str, build_number: str) -> dict:
    query = urllib.parse.urlencode(
        {
            "filter[app]": app_id,
            "filter[preReleaseVersion.version]": version,
            "filter[version]": build_number,
            "limit": "1",
        }
    )
    payload = api_request("GET", token, f"/builds?{query}")
    data = payload.get("data") or []
    if not data:
        raise RuntimeError(
            f"Build {version} ({build_number}) not found yet in App Store Connect."
        )
    return data[0]


def wait_for_build(token: str, app_id: str, version: str, build_number: str) -> dict:
    deadline = time.time() + 45 * 60
    while time.time() < deadline:
        build = find_build(token, app_id, version, build_number)
        state = (build.get("attributes") or {}).get("processingState")
        print(f"Build processing state: {state or 'unknown'}")
        if state in {"VALID", "PROCESSING"}:
            if state == "VALID":
                return build
        elif state in {"FAILED", "INVALID"}:
            raise RuntimeError(f"Build processing failed with state {state}.")
        time.sleep(30)
    raise RuntimeError("Timed out waiting for build processing.")


def set_export_compliance(token: str, build: dict) -> None:
    beta_detail_id = (
        ((build.get("relationships") or {}).get("buildBetaDetail") or {})
        .get("data", {})
        .get("id")
    )
    if not beta_detail_id:
        print("No buildBetaDetail id; skipping export compliance patch.")
        return
    api_request(
        "PATCH",
        token,
        f"/buildBetaDetails/{beta_detail_id}",
        {
            "data": {
                "type": "buildBetaDetails",
                "id": beta_detail_id,
                "attributes": {
                    "autoNotifyEnabled": True,
                    "usesNonExemptEncryption": False,
                },
            }
        },
    )
    print("Export compliance set (standard encryption only).")


def resolve_beta_groups(token: str, app_id: str, names: list[str]) -> list[str]:
    query = urllib.parse.urlencode({"filter[app]": app_id, "limit": "200"})
    payload = api_request("GET", token, f"/betaGroups?{query}")
    groups = payload.get("data") or []
    if not names:
        return [group["id"] for group in groups if group.get("id")]

    wanted = {name.casefold() for name in names}
    matched = []
    for group in groups:
        attrs = group.get("attributes") or {}
        label = (attrs.get("name") or "").casefold()
        if label in wanted:
            matched.append(group["id"])
    if not matched:
        available = ", ".join(
            sorted((g.get("attributes") or {}).get("name", "?") for g in groups)
        )
        raise RuntimeError(
            f"No beta groups matched {names!r}. Available groups: {available}"
        )
    return matched


def assign_groups(token: str, build_id: str, group_ids: list[str]) -> None:
    if not group_ids:
        print("No beta groups to assign.")
        return
    api_request(
        "POST",
        token,
        f"/builds/{build_id}/relationships/betaGroups",
        {
            "data": [
                {"type": "betaGroups", "id": group_id} for group_id in group_ids
            ]
        },
    )
    print(f"Assigned build to {len(group_ids)} beta group(s).")


def resolve_api_credentials(creds: dict, config: dict, project_root: Path) -> dict | None:
    """Merge password upload creds with optional API key file / config for distribute."""
    key_id = (
        creds.get("api_key_id")
        or config.get("asc_api_key_id")
        or ""
    )
    issuer_id = (
        creds.get("issuer_id")
        or config.get("asc_issuer_id")
        or ""
    )
    key_path = creds.get("api_key_path") or creds.get("key_file") or ""

    if creds.get("method") == "api_key":
        key_id = creds.get("api_key_id") or key_id
        issuer_id = creds.get("issuer_id") or issuer_id
        key_path = creds.get("api_key_path") or creds.get("key_file") or key_path

    if not key_id:
        for folder in (
            Path.home() / "Downloads",
            Path.home() / ".appstoreconnect" / "private_keys",
            project_root / "scripts",
        ):
            if not folder.is_dir():
                continue
            matches = sorted(folder.glob("AuthKey_*.p8"))
            if len(matches) == 1:
                key_path = str(matches[0])
                key_id = matches[0].stem.removeprefix("AuthKey_")
                break

    if key_path:
        expanded = Path(key_path).expanduser()
        if expanded.is_file():
            key_path = str(expanded)
        elif key_id:
            for candidate in (
                Path.home() / ".appstoreconnect" / "private_keys" / f"AuthKey_{key_id}.p8",
                Path.home() / "Downloads" / f"AuthKey_{key_id}.p8",
                project_root / "scripts" / f"AuthKey_{key_id}.p8",
            ):
                if candidate.is_file():
                    key_path = str(candidate)
                    break

    if not key_id or not issuer_id or not key_path:
        return None

    return {
        "api_key_id": key_id,
        "issuer_id": issuer_id,
        "api_key_path": key_path,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", required=True, type=Path)
    parser.add_argument("--credentials", required=True, type=Path)
    parser.add_argument("--version", required=True)
    parser.add_argument("--build", required=True)
    parser.add_argument(
        "--wait",
        action="store_true",
        help="Poll until Apple finishes processing the build.",
    )
    args = parser.parse_args()

    config = load_json(args.config)
    creds = load_json(args.credentials)
    project_root = args.config.resolve().parent.parent
    api_creds_file = project_root / "scripts" / "testflight-api-key.json"
    if api_creds_file.is_file():
        creds = {**creds, **load_json(api_creds_file)}
    api = resolve_api_credentials(creds, config, project_root)
    if api is None:
        print(
            "App Store Connect API key not configured for auto-distribute.\n"
            "Run: ./scripts/setup-testflight-api-key.sh <issuer_id>\n"
            "Issuer ID: App Store Connect → Users and Access → Integrations → API"
        )
        return 1

    key_id = api["api_key_id"]
    issuer_id = api["issuer_id"]
    key_path = api["api_key_path"]

    app_id = config.get("asc_app_numeric_id") or ""
    if not app_id:
        print("asc_app_numeric_id missing in app-store-config.json.")
        return 1

    group_names = config.get("testflight_beta_groups") or []
    if isinstance(group_names, str):
        group_names = [group_names]

    private_key = Path(key_path).expanduser().read_text(encoding="utf-8")
    token = make_token(key_id, issuer_id, private_key)

    build = (
        wait_for_build(token, app_id, args.version, args.build)
        if args.wait
        else find_build(token, app_id, args.version, args.build)
    )
    build_id = build["id"]
    set_export_compliance(token, build)
    group_ids = resolve_beta_groups(token, app_id, group_names)
    assign_groups(token, build_id, group_ids)
    print("TestFlight auto-distribute complete. Testers should receive a notification.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except RuntimeError as error:
        print(f"❌ {error}", file=sys.stderr)
        raise SystemExit(1) from error
