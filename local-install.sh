#!/usr/bin/env bash
# Build this fork and install it locally (no Homebrew).
#
# Usage: ./local-install.sh
#
# Sync with upstream every now and then by rebasing onto the newest release
# tag (upstream main may need a newer Swift than the installed toolchain,
# see .swift-version):
#   git fetch upstream --tags
#   git rebase --onto <new-tag> <old-tag> monitor-groups
#   ./local-install.sh
#
# Installs:
#   /Applications/AeroSpace.app  app bundle (skeleton from .local/AeroSpace.app.template)
#   ~/.local/bin/aerospace       CLI
#
# Signing: uses the "aerospace-local-codesign" identity from the login
# keychain if present, so the Accessibility grant survives rebuilds.
# Otherwise falls back to ad-hoc signing, and Accessibility has to be
# re-granted after every install (AeroSpace quits silently until then).
set -euo pipefail
cd "$(dirname "$0")"

app=/Applications/AeroSpace.app
cli_dir="$HOME/.local/bin"
template=.local/AeroSpace.app.template
identity=aerospace-local-codesign
# CommandLineTools ships a broken libc++ include dir ('cassert' not found)
cxx_flags=(-Xcxx -isystem -Xcxx "$(xcrun --show-sdk-path)/usr/include/c++/v1")

swift build -c release --product AeroSpaceApp "${cxx_flags[@]}"
swift build -c release --product aerospace "${cxx_flags[@]}"
bin_path="$(swift build -c release --show-bin-path)"
version="$(git describe --tags)"

osascript -e 'quit app "AeroSpace"' 2> /dev/null || true
sleep 1
pkill -x AeroSpace || true

[ -d "$app" ] || cp -R "$template" "$app"
cp "$bin_path/AeroSpaceApp" "$app/Contents/MacOS/AeroSpace"
cp docs/config-examples/default-config.toml "$app/Contents/Resources/default-config.toml"
plutil -replace CFBundleShortVersionString -string "$version" "$app/Contents/Info.plist"

if security find-identity -p codesigning | grep -q "$identity"; then
    sign_with="$identity"
else
    echo "warning: '$identity' not in keychain, signing ad-hoc - re-grant Accessibility after launch" >&2
    sign_with=-
fi
codesign --force --deep --sign "$sign_with" --identifier bobko.aerospace "$app"

mkdir -p "$cli_dir"
cp "$bin_path/aerospace" "$cli_dir/aerospace"
codesign --force --sign "$sign_with" "$cli_dir/aerospace"

defaults write bobko.aerospace displayStyle i3OrderedByMonitor
open "$app"
echo "Installed AeroSpace $version (signed with: $sign_with)"
