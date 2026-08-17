#!/usr/bin/env python3

import json
import re
import sys
import urllib.error
import urllib.request
from pathlib import Path

SNAPCRAFT_FILE = Path("snap/snapcraft.yaml")
RELEASES_URL = "https://antigravity-hub-auto-updater-974169037036.us-central1.run.app/releases"
URL_TEMPLATE = (
    "https://storage.googleapis.com/antigravity-public/antigravity-hub/"
    "{version}-{build}/{arch}/Antigravity.tar.gz"
)


def fail(message: str) -> "None":
    print(f"::error::{message}")
    raise SystemExit(1)


def fetch_releases() -> list[dict]:
    request = urllib.request.Request(RELEASES_URL, headers={"Accept": "application/json"})
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            payload = response.read().decode("utf-8")
    except (urllib.error.URLError, TimeoutError) as exc:
        fail(f"Failed to fetch release metadata: {exc}")

    try:
        data = json.loads(payload)
    except json.JSONDecodeError as exc:
        fail(f"Invalid release metadata response: {exc}")

    if not isinstance(data, list):
        fail("Invalid release metadata response: expected a list")
    return data


def extract_latest_release(releases: list[dict]) -> tuple[str, str]:
    best: tuple[tuple[int, int, int, int], str, str] | None = None
    for release in releases:
        version = str(release.get("version", "")).strip()
        version_match = re.fullmatch(r"(\d+)\.(\d+)\.(\d+)", version)
        if version_match is None:
            continue

        execution_id = str(release.get("execution_id", "")).strip().rstrip("/")
        if re.fullmatch(r"\d+", execution_id) is None:
            continue

        key = tuple(map(int, version_match.groups())) + (int(execution_id),)
        if best is None or key > best[0]:
            best = (key, version, execution_id)

    if best is None:
        fail("Could not derive latest Antigravity Linux version/build")
    return best[1], best[2]


def main() -> int:
    if not SNAPCRAFT_FILE.is_file():
        fail(f"{SNAPCRAFT_FILE} not found")

    original_text = SNAPCRAFT_FILE.read_text()
    expected_match = re.search(
        r"(?m)^version:\s*['\"]?([^'\"\s]+)['\"]?\s*$",
        original_text,
    )
    if expected_match is None:
        fail(f"Could not read version from {SNAPCRAFT_FILE}")
    expected_version = expected_match.group(1)

    detected_version, detected_build = extract_latest_release(fetch_releases())
    detected_linux_x64 = URL_TEMPLATE.format(
        version=detected_version,
        build=detected_build,
        arch="linux-x64",
    )
    detected_linux_arm = URL_TEMPLATE.format(
        version=detected_version,
        build=detected_build,
        arch="linux-arm",
    )

    changed = False
    if detected_version != expected_version:
        updated_text, c1 = re.subn(
            r"(?m)^version:\s*['\"][^'\"]+['\"]\s*$",
            f"version: '{detected_version}'",
            original_text,
            count=1,
        )
        updated_text, c2 = re.subn(
            r"(?m)^\s*URL=https://.*/linux-x64/Antigravity\.tar\.gz$",
            f"          URL={detected_linux_x64}",
            updated_text,
            count=1,
        )
        updated_text, c3 = re.subn(
            r"(?m)^\s*URL=https://.*/linux-arm/Antigravity\.tar\.gz$",
            f"          URL={detected_linux_arm}",
            updated_text,
            count=1,
        )
        if (c1, c2, c3) != (1, 1, 1):
            fail(f"Failed to patch {SNAPCRAFT_FILE} fields")
        if updated_text != original_text:
            SNAPCRAFT_FILE.write_text(updated_text)
            changed = True

    print(f"expected_version={expected_version}")
    print(f"detected_version={detected_version}")
    print(f"detected_build={detected_build}")
    print(f"detected_linux_x64={detected_linux_x64}")
    print(f"detected_linux_arm={detected_linux_arm}")
    print(f"changed={'true' if changed else 'false'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
