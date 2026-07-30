#!/usr/bin/env bash
# Build and sanity-check the Wear OS APK from an assembled checkout.
#
# Runs inside the assembled flake's `#android` dev shell, which supplies the
# pinned SDK, JDK, and the aapt2 override AGP needs. Gradle comes from the
# project's own wrapper, so the Gradle version is pinned by the source rather
# than by whatever the runner happens to have installed.
#
# The applicationId is not cosmetic: the Wearable Data Layer only routes between
# a phone app and a watch app sharing both applicationId and signing key, so this
# gate builds the identity that actually ships rather than the local default.
#
# Usage: build-watch-apk.sh ASSEMBLED_ROOT [APPLICATION_ID]
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "usage: $0 ASSEMBLED_ROOT [APPLICATION_ID]" >&2
  exit 2
fi

assembled_root="$(realpath "$1")"
application_id="${2:-sh.paseo.assembly}"
: "${ANDROID_HOME:?ANDROID_HOME must be set (run inside nix develop .#android)}"

cd "$assembled_root/packages/watch"

./gradlew --no-daemon --console=plain \
  -PpaseoApplicationId="$application_id" \
  :app:testDebugUnitTest \
  :app:assembleDebug

apk="app/build/outputs/apk/debug/app-debug.apk"
if [[ ! -f "$apk" ]]; then
  echo "::error::expected APK at $apk" >&2
  exit 1
fi

# -L is required: in the Nix-composed SDK each build-tools/<version> is a symlink
# into its own store path, so an unfollowed find descends into nothing and
# reports no aapt2 at all.
aapt2_path="$(find -L "$ANDROID_HOME/build-tools" -type f -name aapt2 | sort -V | tail -n 1)"
if [[ -z "$aapt2_path" ]]; then
  echo "::error::unable to locate aapt2 under ANDROID_HOME" >&2
  exit 1
fi

badging="$("$aapt2_path" dump badging "$apk")"

actual_package="$(sed -n "s/^package: name='\([^']*\)'.*/\1/p" <<<"$badging")"
if [[ "$actual_package" != "$application_id" ]]; then
  echo "::error::unexpected Android package ID: $actual_package (wanted $application_id)" >&2
  exit 1
fi

# Without this uses-feature the watch and the Play Store stop treating it as a
# watch app and it silently becomes an ordinary phone APK, which still installs
# and still launches -- so nothing else would catch the regression.
if ! grep -qF "uses-feature: name='android.hardware.type.watch'" <<<"$badging"; then
  echo "::error::APK does not declare android.hardware.type.watch" >&2
  exit 1
fi

version_name="$(sed -n "s/^package:.*versionName='\([^']*\)'.*/\1/p" <<<"$badging")"
echo "verified: $actual_package $version_name, watch form factor"
echo "apk: $assembled_root/packages/watch/$apk"
