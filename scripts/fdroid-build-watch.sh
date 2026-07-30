#!/usr/bin/env bash
# Build and sign the Wear OS APK from an assembled checkout with the SAME
# identity as the phone APK: applicationId sh.paseo.assembly, signed by the
# same keystore alias.
#
# This is not cosmetic. The Wearable Data Layer only routes between a phone app
# and a watch app that share both applicationId and signing certificate; a
# watch APK signed with any other key can never receive a snapshot from the
# F-Droid phone build, and Play Services reports no error to either side.
#
# Usage: fdroid-build-watch.sh ASSEMBLED_ROOT OUTPUT_APK KEYSTORE PASSWORD_FILE EXPECTED_CERT_SHA256
set -euo pipefail

if [[ $# -ne 5 ]]; then
  echo "usage: $0 ASSEMBLED_ROOT OUTPUT_APK KEYSTORE PASSWORD_FILE EXPECTED_CERT_SHA256" >&2
  exit 2
fi

assembled_root="$(realpath "$1")"
output_apk="$(realpath -m "$2")"
keystore="$(realpath "$3")"
password_file="$(realpath "$4")"
expected_cert_sha256="$(tr -d ':[:space:]' < "$5" | tr '[:upper:]' '[:lower:]')"

: "${PASEO_APP_VERSION:?PASEO_APP_VERSION must be set}"
: "${PASEO_WATCH_VERSION_CODE:?PASEO_WATCH_VERSION_CODE must be set}"

if [[ ! "$PASEO_WATCH_VERSION_CODE" =~ ^[0-9]+$ ]]; then
  echo "PASEO_WATCH_VERSION_CODE must be a positive integer" >&2
  exit 1
fi

cd "$assembled_root/packages/watch"

./gradlew --no-daemon --console=plain \
  -PpaseoApplicationId=sh.paseo.assembly \
  -PpaseoVersionCode="$PASEO_WATCH_VERSION_CODE" \
  -PpaseoVersionName="$PASEO_APP_VERSION" \
  :app:testDebugUnitTest \
  :app:assembleRelease

mapfile -t unsigned_apks < <(
  find app/build/outputs/apk/release -maxdepth 1 -type f -name '*.apk' -print
)
if [[ ${#unsigned_apks[@]} -ne 1 ]]; then
  echo "expected exactly one release APK, found ${#unsigned_apks[@]}" >&2
  printf '  %s\n' "${unsigned_apks[@]}" >&2
  exit 1
fi

# -L is required: in a Nix-composed SDK each build-tools/<version> is a symlink
# into its own store path, and an unfollowed find silently reports nothing.
apksigner_path="$(
  find -L "${ANDROID_HOME:?ANDROID_HOME must be set}/build-tools" -type f -name apksigner |
    sort -V |
    tail -n 1
)"
if [[ -z "$apksigner_path" ]]; then
  echo "unable to locate apksigner under ANDROID_HOME" >&2
  exit 1
fi

mkdir -p "$(dirname "$output_apk")"
export FDROID_KEYSTORE_PASSWORD
FDROID_KEYSTORE_PASSWORD="$(<"$password_file")"
"$apksigner_path" sign \
  --ks "$keystore" \
  --ks-key-alias paseo-assembly \
  --ks-pass env:FDROID_KEYSTORE_PASSWORD \
  --key-pass env:FDROID_KEYSTORE_PASSWORD \
  --out "$output_apk" \
  "${unsigned_apks[0]}"

"$apksigner_path" verify --verbose --print-certs "$output_apk"
actual_cert_sha256="$(
  "$apksigner_path" verify --print-certs "$output_apk" |
    sed -n 's/^.*certificate SHA-256 digest: //p' |
    head -n 1 |
    tr -d ':[:space:]' |
    tr '[:upper:]' '[:lower:]'
)"
if [[ "$actual_cert_sha256" != "$expected_cert_sha256" ]]; then
  echo "APK signing certificate mismatch" >&2
  echo "expected: $expected_cert_sha256" >&2
  echo "actual:   $actual_cert_sha256" >&2
  exit 1
fi

aapt2_path="$(
  find -L "${ANDROID_HOME}/build-tools" -type f -name aapt2 |
    sort -V |
    tail -n 1
)"
badging="$("$aapt2_path" dump badging "$output_apk")"

actual_package="$(sed -n "s/^package: name='\([^']*\)'.*/\1/p" <<<"$badging")"
if [[ "$actual_package" != "sh.paseo.assembly" ]]; then
  echo "::error::unexpected Android package ID: $actual_package" >&2
  exit 1
fi

if ! grep -qF "uses-feature: name='android.hardware.type.watch'" <<<"$badging"; then
  echo "::error::APK does not declare android.hardware.type.watch" >&2
  exit 1
fi

echo "verified: $actual_package $PASEO_APP_VERSION, watch form factor, cert matches"
