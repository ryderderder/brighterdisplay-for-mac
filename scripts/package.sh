#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
existing_app=
expected_sha=
if [ "$#" -ne 0 ]; then
    if [ "$#" -ne 4 ] || [ "$1" != '--existing-app' ] || [ "$3" != '--expected-sha' ]; then
        echo 'Usage: scripts/package.sh [--existing-app /path/to/XDRLift.app --expected-sha SHA256]' >&2
        exit 2
    fi
    existing_app=$2
    expected_sha=$4
    case "$existing_app" in /*) ;; *) echo 'Existing app path must be absolute' >&2; exit 2;; esac
    [ "${#expected_sha}" -eq 64 ] || exit 2
    case "$expected_sha" in *[!a-fA-F0-9]*) exit 2;; esac
fi
./scripts/test.sh
if [ -z "$existing_app" ]; then
    ./scripts/build.sh
    existing_app="$PWD/dist/XDRLift.app"
fi
codesign --verify --strict "$existing_app"
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)
app_version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$existing_app/Contents/Info.plist")
[ "$version" = "$app_version" ] || { echo 'App/source version mismatch' >&2; exit 1; }
actual_sha=$(shasum -a 256 "$existing_app/Contents/MacOS/XDRLift" | awk '{print $1}')
if [ -n "$expected_sha" ] && [ "$actual_sha" != "$expected_sha" ]; then
    echo 'Frozen executable hash mismatch' >&2
    exit 1
fi
mkdir -p .build dist
staging=$(mktemp -d "$PWD/.build/package.XXXXXX")
trap 'rm -rf "$staging"' EXIT HUP INT TERM
while IFS= read -r path; do
    case "$path" in ''|/*|*..*) echo 'Invalid source manifest path' >&2; exit 1;; esac
    [ -f "$path" ] && [ ! -L "$path" ] || { echo "Missing or symlinked source: $path" >&2; exit 1; }
done < .release-files
COPYFILE_DISABLE=1 /usr/bin/ditto -c -k --norsrc --keepParent "$existing_app" "$staging/XDRLift-$version-arm64-PREVIEW.zip"
COPYFILE_DISABLE=1 /usr/bin/zip -q -X "$staging/XDRLift-$version-source.zip" -@ < .release-files
mv "$staging/XDRLift-$version-arm64-PREVIEW.zip" "$staging/XDRLift-$version-source.zip" dist/
(cd dist && shasum -a 256 "XDRLift-$version-arm64-PREVIEW.zip" "XDRLift-$version-source.zip" > SHA256SUMS)
printf 'Packaged %s; executable SHA256 %s\n' "$version" "$actual_sha"
