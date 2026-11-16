#!/usr/bin/env bash
# Write bucket/<name>.json for the latest release of <repo> that carries a
# Windows zip, like `scripts/update.sh kess h4ks-com/kess "Chess..." GPL-3.0-or-later`.
set -euo pipefail

name=$1 repo=$2 description=$3 license=$4
asset="$name-x86_64-pc-windows-msvc.zip"
tag=$(gh release view --repo "$repo" --json tagName --jq .tagName 2>/dev/null) || {
  echo "$name has no release yet"
  exit 0
}
if ! gh release view "$tag" --repo "$repo" --json assets --jq '.assets[].name' | grep -qx "$asset"; then
  echo "$name $tag has no Windows zip"
  exit 0
fi
version=${tag#v}
download=$(mktemp -d)
trap 'rm -rf "$download"' EXIT
gh release download "$tag" --repo "$repo" --pattern "$asset" --dir "$download"
hash=$(sha256sum "$download/$asset" | cut -d ' ' -f 1)
# the zip holds the program either loose or in a folder named after it
bin=$(unzip -Z1 "$download/$asset" | grep -x "\($name/\)\?$name.exe")

jq -n \
  --arg version "$version" \
  --arg description "$description" \
  --arg homepage "https://github.com/$repo" \
  --arg license "$license" \
  --arg url "https://github.com/$repo/releases/download/$tag/$asset" \
  --arg hash "$hash" \
  --arg bin "$bin" \
  --arg autoupdate "https://github.com/$repo/releases/download/v\$version/$asset" \
  '{
    version: $version,
    description: $description,
    homepage: $homepage,
    license: $license,
    notes: "Run it in WezTerm nightly to see its graphics: https://wezterm.org/install/windows.html",
    architecture: {"64bit": {url: $url, hash: $hash}},
    bin: $bin,
    checkver: "github",
    autoupdate: {architecture: {"64bit": {url: $autoupdate}}}
  }' > "bucket/$name.json"
echo "bucket/$name.json now installs $name $version"
