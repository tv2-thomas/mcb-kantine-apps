#!/bin/sh
# Installs Kantine Bar into ~/Applications:
#   curl -fsSL https://raw.githubusercontent.com/tv2-thomas/mcb-kantine-apps/main/install.sh | sh
set -eu

REPO="tv2-thomas/mcb-kantine-apps"
APP="KantineBar.app"
DEST="$HOME/Applications"

fail() {
	echo "✗ $1" >&2
	exit 1
}

[ "$(uname -s)" = "Darwin" ] || fail "Kantine Bar only runs on macOS."
[ "$(uname -m)" = "arm64" ] || fail "Kantine Bar needs an Apple Silicon Mac."
[ "$(sw_vers -productVersion | cut -d. -f1)" -ge 15 ] || fail "Kantine Bar needs macOS 15 or newer."

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

echo "Downloading Kantine Bar…"
curl -fsSL "https://github.com/$REPO/releases/latest/download/KantineBar.zip" -o "$tmp/KantineBar.zip" ||
	fail "Download failed. Check https://github.com/$REPO/releases"
ditto -x -k "$tmp/KantineBar.zip" "$tmp"

if pkill -x KantineBar 2>/dev/null; then
	i=0
	while pgrep -x KantineBar >/dev/null && [ "$i" -lt 25 ]; do
		sleep 0.2
		i=$((i + 1))
	done
fi

mkdir -p "$DEST"
rm -rf "${DEST:?}/$APP"
mv "$tmp/$APP" "$DEST/"
xattr -dr com.apple.quarantine "$DEST/$APP" 2>/dev/null || true
open "$DEST/$APP"

echo "✓ Installed to ~/Applications/$APP"
echo "  Click the fork and knife in the menubar, or press ⇧⌘K."
echo "  Turn on \"Start ved innlogging\" in the ⋯ menu to keep it running after a restart."
