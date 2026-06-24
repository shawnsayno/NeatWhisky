#!/bin/bash
#
# build-wine-libraries.sh — assemble NeatWhisky's `Libraries.tar.gz`.
#
# This file is part of NeatWhisky, a fork of Whisky (GPL-3.0).
#
# Produces the two release assets that `DownloadSources` / `WhiskyWineInstaller`
# expect to find at:
#   https://github.com/<owner>/NeatWhisky/releases/latest/download/Libraries.tar.gz
#   https://github.com/<owner>/NeatWhisky/releases/latest/download/WhiskyWineVersion.plist
#
# The tarball, when extracted with `tar -xzf ... -C "<App Support>/app.neatwhisky"`,
# yields the layout WhiskyKit expects:
#
#   Libraries/
#     WhiskyWineVersion.plist
#     Wine/
#       bin/   (wine, wineserver, wine64 -> wine, winecfg -> wine, ...)
#       lib/   (incl. libMoltenVK.dylib + winevulkan — open-source Vulkan→Metal)
#       share/
#     DXVK/
#       x32/   (d3d10core.dll, d3d11.dll, dxgi.dll)
#       x64/   (d3d10core.dll, d3d11.dll, dxgi.dll)
#
# The whole stack is open source (Wine, DXVK, MoltenVK) and redistributable —
# no GPTK / CrossOver components.
#
# Usage:
#   scripts/build-wine-libraries.sh [--wine-dir DIR] [--dxvk-dir DIR]
#                                   [--version X.Y.Z] [--output DIR]
#
# With no arguments it auto-detects an existing Whisky / NeatWhisky install to
# repackage (the simplest, known-good path). Point --wine-dir / --dxvk-dir at a
# freshly downloaded Wine Staging build (e.g. from Gcenx) for a clean build.

set -euo pipefail

# --- Defaults ---------------------------------------------------------------

VERSION="11.10.0"
OUTPUT_DIR="$(cd "$(dirname "$0")/.." && pwd)/dist"
WINE_DIR=""
DXVK_DIR=""

# Candidate install locations to auto-detect (NeatWhisky first, then Whisky).
APP_SUPPORT="$HOME/Library/Application Support"
CANDIDATES=(
  "$APP_SUPPORT/app.neatwhisky/Libraries"
  "$APP_SUPPORT/com.isaacmarovitz.Whisky/Libraries"
)

# --- Arg parsing ------------------------------------------------------------

usage() {
  grep '^#' "$0" | sed 's/^# \{0,1\}//' | sed '/^!/d'
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --wine-dir) WINE_DIR="$2"; shift 2 ;;
    --dxvk-dir) DXVK_DIR="$2"; shift 2 ;;
    --version)  VERSION="$2";  shift 2 ;;
    --output)   OUTPUT_DIR="$2"; shift 2 ;;
    -h|--help)  usage 0 ;;
    *) echo "Unknown option: $1" >&2; usage 1 ;;
  esac
done

# --- Auto-detect sources ----------------------------------------------------

if [[ -z "$WINE_DIR" || -z "$DXVK_DIR" ]]; then
  for base in "${CANDIDATES[@]}"; do
    if [[ -x "$base/Wine/bin/wine" ]]; then
      [[ -z "$WINE_DIR" ]] && WINE_DIR="$base/Wine"
      [[ -z "$DXVK_DIR" && -d "$base/DXVK" ]] && DXVK_DIR="$base/DXVK"
      break
    fi
  done
fi

if [[ -z "$WINE_DIR" ]]; then
  echo "error: could not find a Wine directory. Pass --wine-dir DIR." >&2
  echo "       (expected a folder containing bin/wine, lib/, share/)" >&2
  exit 1
fi
if [[ -z "$DXVK_DIR" ]]; then
  echo "error: could not find a DXVK directory. Pass --dxvk-dir DIR." >&2
  echo "       (expected a folder containing x32/ and x64/ DLLs)" >&2
  exit 1
fi

# --- Validate ---------------------------------------------------------------

echo "==> Validating sources"
[[ -x "$WINE_DIR/bin/wine" ]] || { echo "error: $WINE_DIR/bin/wine not found/executable" >&2; exit 1; }
[[ -x "$WINE_DIR/bin/wineserver" ]] || { echo "error: $WINE_DIR/bin/wineserver missing" >&2; exit 1; }

if [[ -f "$WINE_DIR/lib/libMoltenVK.dylib" ]]; then
  echo "    MoltenVK: bundled (lib/libMoltenVK.dylib)"
else
  echo "    WARNING: lib/libMoltenVK.dylib not found — Vulkan→Metal may not work." >&2
fi

for arch in x32 x64; do
  for dll in d3d10core.dll d3d11.dll dxgi.dll; do
    [[ -f "$DXVK_DIR/$arch/$dll" ]] || echo "    WARNING: DXVK/$arch/$dll missing" >&2
  done
done

WINE_VERSION_STRING="$("$WINE_DIR/bin/wine" --version 2>/dev/null || echo "unknown")"
echo "    Wine: $WINE_VERSION_STRING"
echo "    Target version tag: $VERSION"

# Split X.Y.Z into components for the version manifest.
IFS='.' read -r MAJOR MINOR PATCH <<< "$VERSION"
MAJOR="${MAJOR:-0}"; MINOR="${MINOR:-0}"; PATCH="${PATCH:-0}"

# --- Stage ------------------------------------------------------------------

STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT
LIBS="$STAGING/Libraries"
mkdir -p "$LIBS"

echo "==> Copying Wine (preserving symlinks)"
ditto "$WINE_DIR" "$LIBS/Wine"

echo "==> Copying DXVK"
ditto "$DXVK_DIR" "$LIBS/DXVK"

# Ensure the wine64 compatibility symlink exists (modern WoW64 ships only `wine`).
if [[ ! -e "$LIBS/Wine/bin/wine64" ]]; then
  echo "==> Creating wine64 -> wine symlink"
  ln -s wine "$LIBS/Wine/bin/wine64"
fi

echo "==> Writing WhiskyWineVersion.plist (version $VERSION)"
write_version_plist() {
  cat > "$1" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>version</key>
	<dict>
		<key>build</key>
		<string>0</string>
		<key>major</key>
		<integer>${MAJOR}</integer>
		<key>minor</key>
		<integer>${MINOR}</integer>
		<key>patch</key>
		<integer>${PATCH}</integer>
		<key>preRelease</key>
		<string></string>
	</dict>
</dict>
</plist>
PLIST
}
write_version_plist "$LIBS/WhiskyWineVersion.plist"

# --- Package ----------------------------------------------------------------

mkdir -p "$OUTPUT_DIR"
TARBALL="$OUTPUT_DIR/Libraries.tar.gz"
MANIFEST="$OUTPUT_DIR/WhiskyWineVersion.plist"

echo "==> Creating $TARBALL (this can take a few minutes)"
tar -C "$STAGING" -czf "$TARBALL" Libraries

# Ship the manifest standalone too (the app fetches it to check for updates).
write_version_plist "$MANIFEST"

# --- Report -----------------------------------------------------------------

SIZE="$(du -h "$TARBALL" | cut -f1)"
SHA="$(shasum -a 256 "$TARBALL" | cut -d' ' -f1)"

echo
echo "==> Done."
echo "    Tarball : $TARBALL ($SIZE)"
echo "    Manifest: $MANIFEST"
echo "    SHA-256 : $SHA"
echo
echo "Next steps:"
echo "  1. Create a GitHub Release (tag e.g. v$VERSION) on the NeatWhisky repo."
echo "  2. Upload BOTH assets to that release:"
echo "       - Libraries.tar.gz"
echo "       - WhiskyWineVersion.plist"
echo "     (DownloadSources points at releases/latest/download/<name>.)"
echo "  3. The app will then download and install Wine automatically."
