#!/usr/bin/env python3
"""
simple_narrate figure renderer.

THIS SCRIPT IS THE DURABLE ARTIFACT, not the PNGs. Re-render from here.
(Per the Substack essay protocol's principle; the technology differs because
the subject is a UI layout rather than a composed illustration -- see the
protocol .md beside this file for why.)

Renders src/fig-*.html through headless Edge at 2x, auto-crops to content,
and prints a WCAG contrast report. ANY FAIL IN THAT REPORT IS A BLOCKER.

Determinism notes:
  - Fonts are VENDORED in src/_fonts/. No network fetch at render time.
  - No randomness anywhere. Same input -> same PNG.
  - The only external dependency is the Edge binary itself.

Usage:  python3 render.py [figure-number ...]
"""

import os, subprocess, sys
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "src")
SCALE = 2

EDGE = r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
EDGE_ALTS = [
    r"C:\Program Files\Microsoft\Edge\Application\msedge.exe",
    r"C:\Program Files\Google\Chrome\Application\chrome.exe",
    r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
]

# (slug, css width, generous css height -- cropped down after)
FIGURES = [
    ("01-editor-window", 1480, 900),
    ("02-block-anatomy", 1180, 700),
    ("03-block-states",  1180, 620),
    ("04-split-preview", 1180, 760),
]

# Foreground / background token pairs that carry meaning. Checked, not eyeballed.
CONTRAST_PAIRS = [
    ("app text on panel",     "#1A2029", "#FFFFFF", 4.5),
    ("app text on bar",       "#1A2029", "#F5F7FA", 4.5),
    ("app text on bg",        "#1A2029", "#E9ECF1", 4.5),
    ("dim text on bar",       "#5A6573", "#F5F7FA", 4.5),
    ("dim text on panel",     "#5A6573", "#FFFFFF", 4.5),
    ("blue chip on wash",     "#1F5FA8", "#C7DAF1", 4.5),
    ("green chip on wash",    "#1D6B52", "#E0F0E9", 4.5),
    ("amber chip on wash",    "#8A5A0B", "#FAF1DD", 4.5),
    ("signal chip on wash",   "#AF3A22", "#F8E7E2", 4.5),
    ("amber warn on panel",   "#8A5A0B", "#FFFFFF", 4.5),
    ("blue link on panel",    "#1F5FA8", "#FFFFFF", 4.5),
    # Split-preview tints must be distinguishable from each other AND carry text.
    ("text on split-upper",   "#1A2029", "#C7DAF1", 4.5),
    ("text on split-lower",   "#1A2029", "#FAF1DD", 4.5),
]


def find_browser():
    for p in [EDGE] + EDGE_ALTS:
        if os.path.exists(p):
            return p
    sys.exit("No Edge or Chrome binary found. Edit EDGE at the top of this script.")


def rel_luminance(hexcolor):
    r, g, b = (int(hexcolor[i:i + 2], 16) / 255 for i in (1, 3, 5))
    f = lambda c: c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = f(r), f(g), f(b)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(fg, bg):
    l1, l2 = rel_luminance(fg), rel_luminance(bg)
    hi, lo = max(l1, l2), min(l1, l2)
    return (hi + 0.05) / (lo + 0.05)


def contrast_report():
    print("\n--- CONTRAST REPORT (WCAG 2.1) ---")
    worst, fails = 99.0, 0
    for name, fg, bg, need in CONTRAST_PAIRS:
        ratio = contrast(fg, bg)
        ok = ratio >= need
        fails += 0 if ok else 1
        worst = min(worst, ratio)
        print(f"  {'PASS' if ok else 'FAIL'}  {ratio:5.2f}:1  (need {need})  {name}")
    # The two split tints must also be distinguishable from one another.
    tint = contrast("#C7DAF1", "#FAF1DD")
    print(f"  {'PASS' if tint >= 1.15 else 'FAIL'}  {tint:5.2f}:1  (need 1.15)  split tints vs each other")
    if tint < 1.15:
        fails += 1
    print(f"--- worst {worst:.2f}:1, {fails} FAIL(S) ---")
    if fails:
        print("\nBLOCKER: fix the palette before shipping these figures.")
    return fails


def autocrop(path, bg_probe=(0, 0), pad=0):
    """Crop uniform border matching the top-left pixel. Deterministic."""
    im = Image.open(path).convert("RGB")
    bg = im.getpixel(bg_probe)
    solid = Image.new("RGB", im.size, bg)
    from PIL import ImageChops
    diff = ImageChops.difference(im, solid)
    box = diff.getbbox()
    if not box:
        return im.size
    l, t, r, b = box
    l, t = max(0, l - pad), max(0, t - pad)
    r, b = min(im.width, r + pad), min(im.height, b + pad)
    im.crop((l, t, r, b)).save(path, optimize=True)
    return (r - l, b - t)


def render(browser, slug, w, h):
    src = os.path.join(SRC, f"fig-{slug}.html").replace("\\", "/")
    out = os.path.join(HERE, f"{slug}.png").replace("\\", "/")
    subprocess.run([
        browser, "--headless=new", "--disable-gpu", "--hide-scrollbars",
        f"--force-device-scale-factor={SCALE}",
        f"--screenshot={out}", f"--window-size={w},{h}",
        f"file:///{src}",
    ], capture_output=True)
    if not os.path.exists(out):
        print(f"  ERROR  {slug}: no output written")
        return False
    size = autocrop(out, pad=SCALE * 8)
    kb = os.path.getsize(out) / 1024
    print(f"  ok     {slug}.png  {size[0]}x{size[1]}  {kb:.0f} KB")
    return True


def main():
    wanted = sys.argv[1:]
    browser = find_browser()
    print(f"Renderer: {browser}")
    print(f"Scale: {SCALE}x   Fonts: vendored (src/_fonts)")
    print("\n--- FIGURES ---")
    for slug, w, h in FIGURES:
        if wanted and not any(slug.startswith(a) for a in wanted):
            continue
        if not os.path.exists(os.path.join(SRC, f"fig-{slug}.html")):
            print(f"  skip   {slug} (no source)")
            continue
        render(browser, slug, w, h)
    fails = contrast_report()
    sys.exit(1 if fails else 0)


if __name__ == "__main__":
    main()
