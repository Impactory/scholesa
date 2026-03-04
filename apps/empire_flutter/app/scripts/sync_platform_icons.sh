#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ICONS_DIR="$ROOT_DIR/assets/icons"
REPO_ROOT="$(cd "$ROOT_DIR/../../.." && pwd)"

ANDROID_SRC="$ICONS_DIR/android"
IOS_SRC="$ICONS_DIR/ios"
WIN_SRC="$ICONS_DIR/windows11"

ANDROID_RES="$ROOT_DIR/android/app/src/main/res"
ANDROID_SPLASH_DIR="$ROOT_DIR/android/app/src/main/res/drawable-nodpi"
IOS_APPICON="$ROOT_DIR/ios/Runner/Assets.xcassets/AppIcon.appiconset"
IOS_LAUNCH_IMAGE="$ROOT_DIR/ios/Runner/Assets.xcassets/LaunchImage.imageset"
MACOS_APPICON="$ROOT_DIR/macos/Runner/Assets.xcassets/AppIcon.appiconset"
WINDOWS_ICON="$ROOT_DIR/windows/runner/resources/app_icon.ico"
FLUTTER_WEB_DIR="$ROOT_DIR/web"
NEXT_PUBLIC_DIR="$REPO_ROOT/public"

echo "[icons] Normalizing brand assets to transparent backgrounds and required formats"
python3 "$ROOT_DIR/scripts/convert_brand_assets.py"

require_file() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    echo "Missing required file: $path" >&2
    exit 1
  fi
}

has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

resize_png() {
  local height="$1"
  local width="$2"
  local src="$3"
  local dst="$4"

  require_file "$src"

  if has_cmd sips; then
    sips -z "$height" "$width" "$src" --out "$dst" >/dev/null
    return
  fi

  if has_cmd magick; then
    magick "$src" -resize "${width}x${height}" "$dst"
    return
  fi

  if has_cmd convert; then
    convert "$src" -resize "${width}x${height}" "$dst"
    return
  fi

  echo "[icons] Warning: no image resize tool found (sips/magick/convert). Copying source without resize: $dst" >&2
  cp "$src" "$dst"
}

convert_to_ico() {
  local src="$1"
  local dst="$2"

  require_file "$src"

  if has_cmd sips; then
    sips -s format ico "$src" --out "$dst" >/dev/null
    return
  fi

  if has_cmd magick; then
    magick "$src" "$dst"
    return
  fi

  if has_cmd convert; then
    convert "$src" "$dst"
    return
  fi

  echo "[icons] Warning: no ico conversion tool found (sips/magick/convert). Copying PNG with .ico extension: $dst" >&2
  cp "$src" "$dst"
}

copy_png() {
  local src="$1"
  local dst="$2"
  require_file "$src"
  cp "$src" "$dst"
}

convert_png_to_opaque() {
  local src="$1"
  local dst="$2"
  require_file "$src"

  # Convert PNG to opaque RGB by removing alpha and filling transparent areas with white
  python3 -c "
from PIL import Image
import sys

src = '$src'
dst = '$dst'

# Load image and convert to RGBA if needed
img = Image.open(src).convert('RGBA')

# Create white background
white_background = Image.new('RGB', img.size, (255, 255, 255))

# Paste image onto white background using alpha channel as mask
white_background.paste(img, (0, 0), img)

# Save as RGB (no alpha)
white_background.save(dst, 'PNG', optimize=True)
print(f'Converted {src} to opaque RGB PNG: {dst}')
  " || {
    # Fallback: just copy if python3 PIL is not available
    echo "Warning: python3 with Pillow not available, copying non-converted icon" >&2
    cp "$src" "$dst"
  }
}

echo "[icons] Syncing Android launcher icons from assets/icons/android"
copy_png "$ANDROID_SRC/android-launchericon-48-48.png" "$ANDROID_RES/mipmap-mdpi/ic_launcher.png"
copy_png "$ANDROID_SRC/android-launchericon-72-72.png" "$ANDROID_RES/mipmap-hdpi/ic_launcher.png"
copy_png "$ANDROID_SRC/android-launchericon-96-96.png" "$ANDROID_RES/mipmap-xhdpi/ic_launcher.png"
copy_png "$ANDROID_SRC/android-launchericon-144-144.png" "$ANDROID_RES/mipmap-xxhdpi/ic_launcher.png"
copy_png "$ANDROID_SRC/android-launchericon-192-192.png" "$ANDROID_RES/mipmap-xxxhdpi/ic_launcher.png"

echo "[icons] Syncing Android native splash logo from transparent source"
mkdir -p "$ANDROID_SPLASH_DIR"
require_file "$IOS_SRC/1024.png"
resize_png 512 512 "$IOS_SRC/1024.png" "$ANDROID_SPLASH_DIR/splash_logo.png"

echo "[icons] Syncing iOS app icons from assets/icons/ios (ensuring opaque RGB format for Apple compliance)"
# iOS app icons MUST be opaque RGB (no alpha channel) per Apple's App Store guidelines
# We convert transparent PNGs to opaque by compositing on white background
convert_png_to_opaque "$IOS_SRC/20.png" "$IOS_APPICON/Icon-App-20x20@1x.png"
convert_png_to_opaque "$IOS_SRC/40.png" "$IOS_APPICON/Icon-App-20x20@2x.png"
convert_png_to_opaque "$IOS_SRC/60.png" "$IOS_APPICON/Icon-App-20x20@3x.png"
convert_png_to_opaque "$IOS_SRC/29.png" "$IOS_APPICON/Icon-App-29x29@1x.png"
convert_png_to_opaque "$IOS_SRC/58.png" "$IOS_APPICON/Icon-App-29x29@2x.png"
convert_png_to_opaque "$IOS_SRC/87.png" "$IOS_APPICON/Icon-App-29x29@3x.png"
convert_png_to_opaque "$IOS_SRC/40.png" "$IOS_APPICON/Icon-App-40x40@1x.png"
convert_png_to_opaque "$IOS_SRC/80.png" "$IOS_APPICON/Icon-App-40x40@2x.png"
convert_png_to_opaque "$IOS_SRC/120.png" "$IOS_APPICON/Icon-App-40x40@3x.png"
convert_png_to_opaque "$IOS_SRC/50.png" "$IOS_APPICON/Icon-App-50x50@1x.png"
convert_png_to_opaque "$IOS_SRC/100.png" "$IOS_APPICON/Icon-App-50x50@2x.png"
convert_png_to_opaque "$IOS_SRC/57.png" "$IOS_APPICON/Icon-App-57x57@1x.png"
convert_png_to_opaque "$IOS_SRC/114.png" "$IOS_APPICON/Icon-App-57x57@2x.png"
convert_png_to_opaque "$IOS_SRC/120.png" "$IOS_APPICON/Icon-App-60x60@2x.png"
convert_png_to_opaque "$IOS_SRC/180.png" "$IOS_APPICON/Icon-App-60x60@3x.png"
convert_png_to_opaque "$IOS_SRC/72.png" "$IOS_APPICON/Icon-App-72x72@1x.png"
convert_png_to_opaque "$IOS_SRC/144.png" "$IOS_APPICON/Icon-App-72x72@2x.png"
convert_png_to_opaque "$IOS_SRC/76.png" "$IOS_APPICON/Icon-App-76x76@1x.png"
convert_png_to_opaque "$IOS_SRC/152.png" "$IOS_APPICON/Icon-App-76x76@2x.png"
convert_png_to_opaque "$IOS_SRC/167.png" "$IOS_APPICON/Icon-App-83.5x83.5@2x.png"
convert_png_to_opaque "$IOS_SRC/1024.png" "$IOS_APPICON/Icon-App-1024x1024@1x.png"

echo "[icons] Syncing macOS app icons from assets/icons/ios"
copy_png "$IOS_SRC/16.png" "$MACOS_APPICON/app_icon_16.png"
copy_png "$IOS_SRC/32.png" "$MACOS_APPICON/app_icon_32.png"
copy_png "$IOS_SRC/64.png" "$MACOS_APPICON/app_icon_64.png"
copy_png "$IOS_SRC/128.png" "$MACOS_APPICON/app_icon_128.png"
copy_png "$IOS_SRC/256.png" "$MACOS_APPICON/app_icon_256.png"
copy_png "$IOS_SRC/512.png" "$MACOS_APPICON/app_icon_512.png"
copy_png "$IOS_SRC/1024.png" "$MACOS_APPICON/app_icon_1024.png"

echo "[icons] Syncing iOS launch image from assets/icons/ios"
require_file "$IOS_SRC/1024.png"
resize_png 168 168 "$IOS_SRC/1024.png" "$IOS_LAUNCH_IMAGE/LaunchImage.png"
resize_png 336 336 "$IOS_SRC/1024.png" "$IOS_LAUNCH_IMAGE/LaunchImage@2x.png"
resize_png 504 504 "$IOS_SRC/1024.png" "$IOS_LAUNCH_IMAGE/LaunchImage@3x.png"

echo "[icons] Generating Windows app_icon.ico from assets/icons/windows11"
require_file "$WIN_SRC/Square44x44Logo.targetsize-256.png"
convert_to_ico "$WIN_SRC/Square44x44Logo.targetsize-256.png" "$WINDOWS_ICON"

echo "[icons] Syncing Flutter web PNG icons from assets/icons/android"
copy_png "$ANDROID_SRC/android-launchericon-192-192.png" "$FLUTTER_WEB_DIR/icons/Icon-192.png"
copy_png "$ANDROID_SRC/android-launchericon-512-512.png" "$FLUTTER_WEB_DIR/icons/Icon-512.png"
copy_png "$ANDROID_SRC/android-launchericon-192-192.png" "$FLUTTER_WEB_DIR/icons/Icon-maskable-192.png"
copy_png "$ANDROID_SRC/android-launchericon-512-512.png" "$FLUTTER_WEB_DIR/icons/Icon-maskable-512.png"
copy_png "$ANDROID_SRC/android-launchericon-192-192.png" "$FLUTTER_WEB_DIR/favicon.png"
resize_png 16 16 "$ANDROID_SRC/android-launchericon-512-512.png" "$FLUTTER_WEB_DIR/icons/favicon-16x16.png"
resize_png 32 32 "$ANDROID_SRC/android-launchericon-512-512.png" "$FLUTTER_WEB_DIR/icons/favicon-32x32.png"
convert_to_ico "$FLUTTER_WEB_DIR/icons/favicon-32x32.png" "$FLUTTER_WEB_DIR/icons/favicon.ico"

echo "[icons] Syncing Next.js public PNG icons from assets/icons/android"
copy_png "$ANDROID_SRC/android-launchericon-192-192.png" "$NEXT_PUBLIC_DIR/icons/icon-192.png"
copy_png "$ANDROID_SRC/android-launchericon-512-512.png" "$NEXT_PUBLIC_DIR/icons/icon-512.png"
resize_png 32 32 "$ANDROID_SRC/android-launchericon-512-512.png" "$NEXT_PUBLIC_DIR/favicon.png"
convert_to_ico "$NEXT_PUBLIC_DIR/favicon.png" "$NEXT_PUBLIC_DIR/favicon.ico"

echo "[icons] Platform icon sync complete."
