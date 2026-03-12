#!/usr/bin/env python3
"""
Normalize Scholesa brand assets to transparent-background formats.

Outputs:
- apps/empire_flutter/app/assets/icons/android/*.png
- apps/empire_flutter/app/assets/icons/ios/*.png
- apps/empire_flutter/app/assets/icons/scholesa_launcher*.png
- apps/empire_flutter/app/web/icons/*.png + favicon.ico
- apps/empire_flutter/app/web/favicon.png
- public/icons/*.png + favicon.png + favicon.ico
- public/logo/*.png + .webp
"""

from __future__ import annotations

from collections import Counter, deque
from pathlib import Path
from typing import Iterable

from PIL import Image


APP_ROOT = Path(__file__).resolve().parents[1]
REPO_ROOT = APP_ROOT.parents[2]

ASSETS_DIR = APP_ROOT / "assets" / "icons"
ANDROID_DIR = ASSETS_DIR / "android"
IOS_DIR = ASSETS_DIR / "ios"
WEB_DIR = APP_ROOT / "web"
WEB_ICONS_DIR = WEB_DIR / "icons"
PUBLIC_DIR = REPO_ROOT / "public"
PUBLIC_ICONS_DIR = PUBLIC_DIR / "icons"
PUBLIC_LOGO_DIR = PUBLIC_DIR / "logo"

SHARED_MASTER_SOURCE_CANDIDATES = [
    ASSETS_DIR / "scholesa_brand_mark_master.png",
    ASSETS_DIR / "scholesa_launcher.png",
    IOS_DIR / "1024.png",
]

ANDROID_SIZES = [48, 72, 96, 144, 192, 512]
IOS_SIZES = [
    16, 20, 29, 32, 40, 50, 57, 58, 60, 64, 72, 76, 80, 87, 100, 114, 120,
    128, 144, 152, 167, 180, 192, 256, 512, 1024,
]


def ensure_dir(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)


def pick_master_source(candidates: Iterable[Path]) -> Path:
    for candidate in candidates:
        if candidate.exists():
            return candidate
    raise FileNotFoundError("No brand icon source found.")


def color_distance(a: tuple[int, int, int], b: tuple[int, int, int]) -> int:
    return abs(a[0] - b[0]) + abs(a[1] - b[1]) + abs(a[2] - b[2])


def remove_edge_background_to_alpha(img: Image.Image, tolerance: int = 18) -> Image.Image:
    """
    Removes an edge-connected flat background by converting it to transparent.
    Safe for the current launcher asset where the background is edge-connected.
    """
    rgba = img.convert("RGBA")
    width, height = rgba.size
    pixels = rgba.load()

    corners = [
        pixels[0, 0][:3],
        pixels[width - 1, 0][:3],
        pixels[0, height - 1][:3],
        pixels[width - 1, height - 1][:3],
    ]
    bg_rgb = Counter(corners).most_common(1)[0][0]

    queue: deque[tuple[int, int]] = deque()
    visited: set[tuple[int, int]] = set()

    for x in range(width):
        queue.append((x, 0))
        queue.append((x, height - 1))
    for y in range(height):
        queue.append((0, y))
        queue.append((width - 1, y))

    while queue:
        x, y = queue.popleft()
        if (x, y) in visited:
            continue
        visited.add((x, y))

        r, g, b, a = pixels[x, y]
        if a == 0:
            continue
        if color_distance((r, g, b), bg_rgb) > tolerance:
            continue

        pixels[x, y] = (r, g, b, 0)

        if x > 0:
            queue.append((x - 1, y))
        if x < width - 1:
            queue.append((x + 1, y))
        if y > 0:
            queue.append((x, y - 1))
        if y < height - 1:
            queue.append((x, y + 1))

    return rgba


def remove_lockup_background_to_alpha(
    img: Image.Image,
    tolerance: int = 52,
    min_aspect_ratio: float = 1.25,
) -> Image.Image:
    """
    Removes edge-connected background inside the non-transparent content box.
    This handles horizontal lockup assets where the white strip is surrounded
    by transparent padding and therefore not connected to the full image edges.
    """
    rgba = img.convert("RGBA")
    width, height = rgba.size
    if width == 0 or height == 0:
        return rgba

    alpha = rgba.getchannel("A")
    mask = alpha.point(lambda v: 255 if v > 0 else 0)
    bbox = mask.getbbox()
    if not bbox:
        return rgba

    x0, y0, x1, y1 = bbox
    box_w = x1 - x0
    box_h = y1 - y0
    if box_w <= 0 or box_h <= 0:
        return rgba

    aspect_ratio = box_w / box_h
    if aspect_ratio < min_aspect_ratio:
        return rgba

    pixels = rgba.load()
    border_colors: list[tuple[int, int, int]] = []

    for x in range(x0, x1):
        top = pixels[x, y0]
        bottom = pixels[x, y1 - 1]
        if top[3] > 0:
            border_colors.append(top[:3])
        if bottom[3] > 0:
            border_colors.append(bottom[:3])

    for y in range(y0, y1):
        left = pixels[x0, y]
        right = pixels[x1 - 1, y]
        if left[3] > 0:
            border_colors.append(left[:3])
        if right[3] > 0:
            border_colors.append(right[:3])

    if not border_colors:
        return rgba

    bg_rgb = Counter(border_colors).most_common(1)[0][0]
    channel_span = max(bg_rgb) - min(bg_rgb)
    mean_luma = sum(bg_rgb) / 3
    if channel_span > 45 or mean_luma < 150:
        return rgba

    queue: deque[tuple[int, int]] = deque()
    visited: set[tuple[int, int]] = set()

    for x in range(x0, x1):
        queue.append((x, y0))
        queue.append((x, y1 - 1))
    for y in range(y0, y1):
        queue.append((x0, y))
        queue.append((x1 - 1, y))

    while queue:
        x, y = queue.popleft()
        if (x, y) in visited:
            continue
        visited.add((x, y))

        r, g, b, a = pixels[x, y]
        if a == 0:
            continue
        if color_distance((r, g, b), bg_rgb) > tolerance:
            continue

        pixels[x, y] = (r, g, b, 0)

        if x > x0:
            queue.append((x - 1, y))
        if x < x1 - 1:
            queue.append((x + 1, y))
        if y > y0:
            queue.append((x, y - 1))
        if y < y1 - 1:
            queue.append((x, y + 1))

    return rgba


def has_visible_transparency(img: Image.Image) -> bool:
    alpha = img.getchannel("A")
    mn, _mx = alpha.getextrema()
    return mn < 255


def load_normalized_master(candidates: Iterable[Path]) -> Image.Image:
    source = pick_master_source(candidates)
    img = Image.open(source).convert("RGBA")

    if not has_visible_transparency(img):
        img = remove_edge_background_to_alpha(img)

    img = remove_lockup_background_to_alpha(img)
    return img


def resize_icon(img: Image.Image, size: int) -> Image.Image:
    return img.resize((size, size), Image.Resampling.LANCZOS)


def save_png(img: Image.Image, output: Path) -> None:
    ensure_dir(output.parent)
    img.save(output, format="PNG", optimize=True)


def save_webp(img: Image.Image, output: Path) -> None:
    ensure_dir(output.parent)
    img.save(output, format="WEBP", lossless=True, method=6, quality=100)


def write_many_png(master: Image.Image, outputs: Iterable[tuple[Path, int]]) -> None:
    for output, size in outputs:
        save_png(resize_icon(master, size), output)


def generate_assets(shared_master: Image.Image) -> None:
    # Persist normalized transparent launcher source.
    save_png(resize_icon(shared_master, 512), ASSETS_DIR / "scholesa_launcher.png")
    save_png(shared_master, ASSETS_DIR / "scholesa_launcher_transparent.png")

    # Android source icons.
    write_many_png(
        shared_master,
        (
            (ANDROID_DIR / f"android-launchericon-{size}-{size}.png", size)
            for size in ANDROID_SIZES
        ),
    )

    # iOS/macOS source icons.
    write_many_png(
        shared_master,
        (
            (IOS_DIR / f"{size}.png", size)
            for size in IOS_SIZES
        ),
    )

    # Flutter web/PWA icons + favicon.
    write_many_png(
        shared_master,
        [
            (WEB_ICONS_DIR / "Icon-192.png", 192),
            (WEB_ICONS_DIR / "Icon-512.png", 512),
            (WEB_ICONS_DIR / "Icon-maskable-192.png", 192),
            (WEB_ICONS_DIR / "Icon-maskable-512.png", 512),
            (WEB_ICONS_DIR / "favicon-16x16.png", 16),
            (WEB_ICONS_DIR / "favicon-32x32.png", 32),
            (WEB_DIR / "favicon.png", 192),
        ],
    )

    favicon32 = resize_icon(shared_master, 32)
    ensure_dir(WEB_ICONS_DIR)
    favicon32.save(
        WEB_ICONS_DIR / "favicon.ico",
        format="ICO",
        sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64)],
    )

    # Next.js public icons + favicon.
    write_many_png(
        shared_master,
        [
            (PUBLIC_ICONS_DIR / "icon-192.png", 192),
            (PUBLIC_ICONS_DIR / "icon-512.png", 512),
            (PUBLIC_DIR / "favicon.png", 32),
        ],
    )

    favicon64 = resize_icon(shared_master, 64)
    ensure_dir(PUBLIC_DIR)
    favicon64.save(
        PUBLIC_DIR / "favicon.ico",
        format="ICO",
        sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64)],
    )

    # Logo exports in multiple transparent formats.
    write_many_png(
        shared_master,
        [
            (PUBLIC_LOGO_DIR / "scholesa-logo-1024.png", 1024),
            (PUBLIC_LOGO_DIR / "scholesa-logo-512.png", 512),
            (PUBLIC_LOGO_DIR / "scholesa-logo-256.png", 256),
            (PUBLIC_LOGO_DIR / "scholesa-logo-192.png", 192),
            (PUBLIC_LOGO_DIR / "scholesa-logo-128.png", 128),
            (PUBLIC_LOGO_DIR / "scholesa-logo-64.png", 64),
        ],
    )
    save_webp(resize_icon(shared_master, 512), PUBLIC_LOGO_DIR / "scholesa-logo-512.webp")


def main() -> None:
    shared_master = load_normalized_master(SHARED_MASTER_SOURCE_CANDIDATES)
    generate_assets(shared_master)
    print("Brand icon/logo assets converted with transparent background and regenerated.")


if __name__ == "__main__":
    main()
