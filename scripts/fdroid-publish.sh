#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 9 ]]; then
  echo "usage: $0 TARGET_ROOT APK WATCH_APK KEYSTORE PASSWORD_FILE VERSION_NAME WATCH_VERSION_CODE SOURCE_TREE FINGERPRINT" >&2
  exit 2
fi

script_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
target_root="$(realpath "$1")"
apk="$(realpath "$2")"
watch_apk="$(realpath "$3")"
keystore="$(realpath "$4")"
password_file="$(realpath "$5")"
version_name="$6"
watch_version_code="$7"
source_tree="$8"
fingerprint="$(tr -d ':[:space:]' <<<"$9" | tr '[:lower:]' '[:upper:]')"
repo_url="https://colonelpanic8.github.io/paseo-assembly-fdroid/fdroid/repo"
add_repo_url="${repo_url}?fingerprint=${fingerprint}"
watch_url="https://colonelpanic8.github.io/paseo-assembly-fdroid/watch/paseo-watch.apk"

if [[ ! "$watch_version_code" =~ ^[0-9]+$ ]]; then
  echo "WATCH_VERSION_CODE must be a positive integer" >&2
  exit 1
fi

mkdir -p \
  "$target_root/fdroid/repo" \
  "$target_root/fdroid/metadata" \
  "$target_root/fdroid/config" \
  "$target_root/watch" \
  "$target_root/provenance"
cp "$script_root/fdroid/config.yml" "$target_root/fdroid/config.yml"
chmod 600 "$target_root/fdroid/config.yml"
cp \
  "$script_root/fdroid/config/categories.yml" \
  "$target_root/fdroid/config/categories.yml"
cp \
  "$script_root/fdroid/metadata/sh.paseo.assembly.yml" \
  "$target_root/fdroid/metadata/sh.paseo.assembly.yml"
cp "$apk" "$target_root/fdroid/repo/$(basename "$apk")"
cp "$watch_apk" "$target_root/watch/paseo-watch.apk"
watch_sha256="$(sha256sum "$watch_apk" | cut -d' ' -f1)"

export FDROID_KEYSTORE="$keystore"
export FDROID_KEYSTORE_PASSWORD
FDROID_KEYSTORE_PASSWORD="$(<"$password_file")"
(
  cd "$target_root/fdroid"
  fdroid update --pretty
  # Clients only ever read repo/, but archive/ is under the Pages root and every
  # build landed there permanently, which pushed the site past the 1 GB Pages
  # limit and froze the published index. Drop the demoted APKs and reindex so the
  # archive index matches what is left on disk.
  if compgen -G "archive/*.apk" > /dev/null; then
    rm -f archive/*.apk
    fdroid update --pretty
  fi
)

cp "$script_root/fdroid/site/index.html" "$target_root/index.html"
python3 - "$target_root/index.html" "$add_repo_url" "$version_name" "$source_tree" "$fingerprint" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
replacements = {
    "@@ADD_REPO_URL@@": sys.argv[2],
    "@@VERSION_NAME@@": sys.argv[3],
    "@@SOURCE_TREE@@": sys.argv[4],
    "@@FINGERPRINT@@": sys.argv[5],
}
text = path.read_text()
for needle, replacement in replacements.items():
    text = text.replace(needle, replacement)
path.write_text(text)
PY

python3 - \
  "$target_root/watch/latest.json" \
  "$watch_version_code" \
  "$version_name" \
  "$watch_url" \
  "$watch_sha256" \
  "$fingerprint" <<'PY'
import json
from pathlib import Path
import sys

path = Path(sys.argv[1])
path.write_text(json.dumps({
    "packageName": "sh.paseo.assembly",
    "versionCode": int(sys.argv[2]),
    "versionName": sys.argv[3],
    "url": sys.argv[4],
    "sha256": sys.argv[5],
    "certificateSha256": sys.argv[6].lower(),
}, indent=2) + "\n")
PY

touch "$target_root/.nojekyll"
