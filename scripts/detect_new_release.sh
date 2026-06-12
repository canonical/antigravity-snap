#!/usr/bin/env bash
set -euo pipefail

snapcraft_file="snap/snapcraft.yaml"

if [ ! -f "${snapcraft_file}" ]; then
  echo "::error::${snapcraft_file} not found"
  exit 1
fi

expected_version="$(sed -nE "s/^version:[[:space:]]*['\"]?([^'\"[:space:]]+)['\"]?[[:space:]]*$/\1/p" "${snapcraft_file}" | head -n1)"
if [ -z "${expected_version}" ]; then
  echo "::error::Could not read version from ${snapcraft_file}"
  exit 1
fi

html="$(curl -fsSL --compressed https://antigravity.google/releases)"
main_js_path="$(printf '%s' "${html}" | grep -Eo 'main-[^"]+\.js' | head -n1)"
if [ -z "${main_js_path}" ]; then
  echo "::error::Could not find releases JS bundle"
  exit 1
fi

js="$(curl -fsSL --compressed "https://antigravity.google/${main_js_path}")"
linux_urls="$(printf '%s' "${js}" \
  | tr '"' '\n' \
  | grep -E '^https://storage\.googleapis\.com/antigravity-public/antigravity-hub/[0-9]+\.[0-9]+\.[0-9]+-[0-9]+/linux-(x64|arm)/Antigravity\.tar\.gz$' \
  | sort -u || true)"

if [ -z "${linux_urls}" ]; then
  echo "::error::No allowlisted Antigravity Linux release URLs found"
  exit 1
fi

latest_release="$(printf '%s\n' "${linux_urls}" \
  | sed -n 's#.*\/\([0-9]\+\.[0-9]\+\.[0-9]\+\)-\([0-9]\+\)\/linux-.*#\1 \2#p' \
  | sort -k1,1V -k2,2n \
  | tail -n1)"

detected_version="$(printf '%s' "${latest_release}" | awk '{print $1}')"
detected_build="$(printf '%s' "${latest_release}" | awk '{print $2}')"

if [ -z "${detected_version}" ] || [ -z "${detected_build}" ]; then
  echo "::error::Could not derive latest Antigravity Linux version/build"
  exit 1
fi

detected_linux_x64="$(printf '%s\n' "${linux_urls}" | grep "/${detected_version}-${detected_build}/linux-x64/" | head -n1 || true)"
detected_linux_arm="$(printf '%s\n' "${linux_urls}" | grep "/${detected_version}-${detected_build}/linux-arm/" | head -n1 || true)"

if [ -z "${detected_linux_x64}" ] || [ -z "${detected_linux_arm}" ]; then
  echo "::error::Missing linux-x64 or linux-arm URL for ${detected_version}-${detected_build}"
  exit 1
fi

changed=false
if [ "${detected_version}" != "${expected_version}" ]; then
  DETECTED_VERSION="${detected_version}" \
  DETECTED_LINUX_X64="${detected_linux_x64}" \
  DETECTED_LINUX_ARM="${detected_linux_arm}" \
  python3 -c 'import os,re; from pathlib import Path; p=Path("snap/snapcraft.yaml"); t=p.read_text(); v=os.environ["DETECTED_VERSION"]; x=os.environ["DETECTED_LINUX_X64"]; a=os.environ["DETECTED_LINUX_ARM"]; t,c1=re.subn(r"(?m)^version:\s*\x27.*\x27$", f"version: \x27{v}\x27", t, count=1); t,c2=re.subn(r"(?m)^\s*URL=https://.*/linux-x64/Antigravity\.tar\.gz$", f"          URL={x}", t, count=1); t,c3=re.subn(r"(?m)^\s*URL=https://.*/linux-arm/Antigravity\.tar\.gz$", f"          URL={a}", t, count=1); assert c1==1 and c2==1 and c3==1, "Failed to patch snap/snapcraft.yaml fields"; p.write_text(t)'

  if ! git --no-pager diff --quiet -- "${snapcraft_file}"; then
    changed=true
  fi
fi

printf 'expected_version=%s\n' "${expected_version}"
printf 'detected_version=%s\n' "${detected_version}"
printf 'detected_build=%s\n' "${detected_build}"
printf 'detected_linux_x64=%s\n' "${detected_linux_x64}"
printf 'detected_linux_arm=%s\n' "${detected_linux_arm}"
printf 'changed=%s\n' "${changed}"
