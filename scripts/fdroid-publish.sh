#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 7 ]]; then
  echo "usage: $0 TARGET_ROOT APK KEYSTORE PASSWORD_FILE VERSION_NAME SOURCE_TREE FINGERPRINT" >&2
  exit 2
fi

script_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
target_root="$(realpath "$1")"
apk="$(realpath "$2")"
keystore="$(realpath "$3")"
password_file="$(realpath "$4")"
version_name="$5"
source_tree="$6"
fingerprint="$(tr -d ':[:space:]' <<<"$7" | tr '[:lower:]' '[:upper:]')"
repo_url="https://colonelpanic8.github.io/paseo-assembly-fdroid/fdroid/repo"
add_repo_url="${repo_url}?fingerprint=${fingerprint}"

mkdir -p \
  "$target_root/fdroid/repo" \
  "$target_root/fdroid/metadata" \
  "$target_root/fdroid/config" \
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

export FDROID_KEYSTORE="$keystore"
export FDROID_KEYSTORE_PASSWORD
FDROID_KEYSTORE_PASSWORD="$(<"$password_file")"
(
  cd "$target_root/fdroid"
  fdroid update --pretty
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

touch "$target_root/.nojekyll"
