#!/usr/bin/env bash
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
: "${PASEO_NATIVE_BUILD_VERSION_CODE:?PASEO_NATIVE_BUILD_VERSION_CODE must be set}"

if [[ ! "$PASEO_NATIVE_BUILD_VERSION_CODE" =~ ^[0-9]+$ ]]; then
  echo "PASEO_NATIVE_BUILD_VERSION_CODE must be a positive integer" >&2
  exit 1
fi

export APP_VARIANT=assembly
export PASEO_FDROID_BUILD=1

# Build provenance: Metro inlines EXPO_PUBLIC_* into the client bundle during
# the Gradle bundle task, the same way `expo export` does for the desktop
# renderer (see nix/build-info.nix on the assembled branch). All or none: a
# date or repo URL without a commit is worse than reporting no provenance.
if [[ -n "${PASEO_BUILD_COMMIT:-}" ]]; then
  export EXPO_PUBLIC_PASEO_BUILD_COMMIT="$PASEO_BUILD_COMMIT"
  if [[ -n "${PASEO_BUILD_COMMIT_DATE:-}" ]]; then
    export EXPO_PUBLIC_PASEO_BUILD_COMMIT_DATE="$PASEO_BUILD_COMMIT_DATE"
  fi
  if [[ -n "${PASEO_BUILD_COMMIT_MESSAGE:-}" ]]; then
    export EXPO_PUBLIC_PASEO_BUILD_COMMIT_MESSAGE="$PASEO_BUILD_COMMIT_MESSAGE"
  fi
  if [[ -n "${PASEO_BUILD_REPO_URL:-}" ]]; then
    export EXPO_PUBLIC_PASEO_BUILD_REPO_URL="$PASEO_BUILD_REPO_URL"
  fi
fi
export GRADLE_OPTS='-Dorg.gradle.jvmargs="-Xmx4g -XX:MaxMetaspaceSize=1g -XX:+HeapDumpOnOutOfMemoryError -Dfile.encoding=UTF-8" -Dorg.gradle.parallel=false -Dorg.gradle.workers.max=1 -Dorg.gradle.daemon=false'

cd "$assembled_root"
npm ci --include=dev
npm run build:app-deps
npm --prefix packages/app run build:terminal-webview

cd packages/app
npx expo prebuild --platform android --clean --non-interactive

cd android
./gradlew \
  :app:assembleRelease \
  -PreactNativeArchitectures=arm64-v8a \
  --no-daemon \
  --max-workers=1 \
  -Dorg.gradle.parallel=false

mapfile -t unsigned_apks < <(
  find app/build/outputs/apk/release -maxdepth 1 -type f -name '*.apk' -print
)
if [[ ${#unsigned_apks[@]} -ne 1 ]]; then
  echo "expected exactly one release APK, found ${#unsigned_apks[@]}" >&2
  printf '  %s\n' "${unsigned_apks[@]}" >&2
  exit 1
fi

apksigner_path="$(
  find "${ANDROID_HOME:?ANDROID_HOME must be set}/build-tools" -type f -name apksigner |
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

apkanalyzer_path="$(
  find "${ANDROID_HOME}/cmdline-tools" -type f -name apkanalyzer |
    sort -V |
    tail -n 1
)"
if [[ -n "$apkanalyzer_path" ]]; then
  actual_package="$("$apkanalyzer_path" manifest application-id "$output_apk")"
  actual_version_code="$("$apkanalyzer_path" manifest version-code "$output_apk")"
  expected_version_code="$((PASEO_NATIVE_BUILD_VERSION_CODE * 10 + 2))"

  [[ "$actual_package" == "sh.paseo.assembly" ]] || {
    echo "unexpected Android package ID: $actual_package" >&2
    exit 1
  }
  [[ "$actual_version_code" == "$expected_version_code" ]] || {
    echo "unexpected Android version code: $actual_version_code" >&2
    echo "expected Android version code: $expected_version_code" >&2
    exit 1
  }
fi
