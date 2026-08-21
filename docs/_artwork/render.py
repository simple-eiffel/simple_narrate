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
# Screenshots only. Figures 02-04 are Pillow ARGUMENT GRAPHICS -- see ARG_FIGURES.
FIGURES = [
    ("01-editor-window", 1480, 900),
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
    ("signal text on panel",  "#AF3A22", "#FFFFFF", 4.5),
    ("green text on panel",   "#1D6B52", "#FFFFFF", 4.5),
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


# ================================================================ argument figures
# Figures 02-04 are ARGUMENT GRAPHICS, not screenshots: one claim made visible
# per figure, Pillow-composed. Same tokens as the app skin, same vendored fonts,
# no randomness -- same input, same pixels. (No film grain here: that texture
# belonged to the essay series' night-corridor world; this subject's world is
# clean drafting paper.)

from PIL import ImageDraw, ImageFont

AW, AH = 1600, 1000
MARG = 90

GROUND = "#E9ECF1"; PANEL = "#FFFFFF"; BAR = "#F5F7FA"; HAIR = "#D3DAE3"
INK = "#1A2029"; DIM = "#5A6573"
BLUE = "#1F5FA8"; GREEN = "#1D6B52"; AMBER = "#8A5A0B"; SIGNAL = "#AF3A22"
W_BLUE = "#C7DAF1"; W_GREEN = "#E0F0E9"; W_AMBER = "#FAF1DD"; W_SIG = "#F8E7E2"

_axes_warned = [False]


def _font(name, size, axes=None):
    """axes: {"wght": 700, ...}. Values are matched to the font's OWN fvar
    order by axis name -- never by guessed position. (The first render guessed
    [wdth, wght] for Archivo, and every headline came out Thin-Expanded.)"""
    f = ImageFont.truetype(os.path.join(SRC, "_fonts", name), size)
    if axes:
        try:
            key = {"weight": "wght", "width": "wdth", "optical": "opsz",
                   "italic": "ital", "slant": "slnt"}
            vals = []
            for ax in f.get_variation_axes():
                nm = ax["name"]
                nm = (nm.decode() if isinstance(nm, (bytes, bytearray)) else str(nm))
                nm = nm.strip("\x00 ").lower()
                tag = next((t for k, t in key.items() if k in nm), None)
                vals.append(axes.get(tag, ax["default"]))
            f.set_variation_by_axes(vals)
        except Exception:
            if not _axes_warned[0]:
                print("  warn   variable-font axes unsupported; text renders Regular")
                _axes_warned[0] = True
    return f


def archivo(size, wght=700):  return _font("Archivo.ttf", size, {"wght": wght})
def literata(size, wght=400): return _font("Literata.ttf", size, {"opsz": 24, "wght": wght})
def plex(size):               return _font("IBMPlexMono.ttf", size)


def tracked(d, xy, text, font, fill, tracking=0):
    x, y = xy
    for ch in text:
        d.text((x, y), ch, font=font, fill=fill)
        x += d.textlength(ch, font=font) + tracking
    return x


def tracked_w(d, text, font, tracking=0):
    return sum(d.textlength(ch, font=font) + tracking for ch in text) - (tracking if text else 0)


def masthead(d, eyebrow, headline):
    tracked(d, (MARG, 64), eyebrow.upper(), plex(21), DIM, tracking=3)
    size = 58                                     # shrink-to-fit, never overflow
    f = archivo(size, 700)
    while d.textlength(headline, font=f) > AW - 2 * MARG and size > 40:
        size -= 2
        f = archivo(size, 700)
    d.text((MARG, 160 - size), headline, font=f, fill=INK)
    d.rectangle((MARG, 196, AW - MARG, 199), fill=INK)


def foot(d, left, right):
    d.rectangle((MARG, AH - 80, AW - MARG, AH - 79), fill=HAIR)
    d.text((MARG, AH - 62), left, font=plex(19), fill=DIM)
    d.text((AW - MARG - d.textlength(right, font=plex(19)), AH - 62),
           right, font=plex(19), fill=DIM)


def chip(d, x, y, text, fg, bg, border):
    f = plex(19)
    tr, pad_x, pad_y = 2, 12, 7
    w = tracked_w(d, text, f, tr)
    d.rounded_rectangle((x, y, x + w + 2 * pad_x, y + 33), radius=5,
                        fill=bg, outline=border, width=2)
    tracked(d, (x + pad_x, y + pad_y - 1), text, f, fg, tracking=tr)
    return x + w + 2 * pad_x


def warn_glyph(d, x, y, s=20, color=AMBER):
    d.polygon([(x + s / 2, y), (x, y + s), (x + s, y + s)], fill=color)
    d.rectangle((x + s / 2 - 1, y + 7, x + s / 2 + 1, y + s - 8), fill=PANEL)
    d.rectangle((x + s / 2 - 1, y + s - 6, x + s / 2 + 1, y + s - 4), fill=PANEL)


def wrap_words(d, text, font, maxw):
    """-> lines; each line is a list of (word, x_offset). Deterministic."""
    space = d.textlength(" ", font=font)
    lines, cur, x = [], [], 0.0
    for w in text.split():
        wl = d.textlength(w, font=font)
        if cur and x + wl > maxw:
            lines.append(cur)
            cur, x = [], 0.0
        cur.append((w, x))
        x += wl + space
    if cur:
        lines.append(cur)
    return lines


def draw_par(d, lines, x, y, lh, font, fill=INK):
    for i, ln in enumerate(lines):
        for wtext, wx in ln:
            d.text((x + wx, y + i * lh), wtext, font=font, fill=fill)


def range_boxes(d, lines, font, x, y, lh, box_h, w_from, w_to):
    """One box per line covering global word indices [w_from, w_to)."""
    out, gi = [], 0
    for li, ln in enumerate(lines):
        s, e = gi, gi + len(ln)
        gi = e
        a, b = max(w_from, s), min(w_to, e)
        if a >= b:
            continue
        x0 = x + ln[a - s][1]
        last_word, last_x = ln[b - s - 1]
        x1 = x + last_x + d.textlength(last_word, font=font)
        out.append((x0 - 3, y + li * lh - 4, x1 + 3, y + li * lh - 4 + box_h))
    return out


def fig_02(path):
    im = Image.new("RGB", (AW, AH), GROUND)
    d = ImageDraw.Draw(im)
    masthead(d, "simple_narrate · block state", "Five facts, one glance.")

    mono = plex(26)
    y = 272
    for name, val in [("is_dirty", "True"), ("has_render", "True"),
                      ("is_approved", "False"), ("warning_count", "1"),
                      ("fidelity", "—")]:
        d.text((MARG, y), name, font=mono, fill=DIM)
        d.text((MARG + 340, y), val, font=mono, fill=INK)
        y += 52
    d.text((MARG, y + 24), "Every block answers five questions at once.",
           font=literata(24), fill=DIM)

    ax0, ax1, ay = 640, 796, 400
    d.line((ax0, ay, ax1, ay), fill=INK, width=3)
    d.polygon([(ax1 + 4, ay), (ax1 - 14, ay - 10), (ax1 - 14, ay + 10)], fill=INK)
    lbl = "collapses to"
    d.text(((ax0 + ax1) / 2 - d.textlength(lbl, font=plex(19)) / 2, ay - 42),
           lbl, font=plex(19), fill=DIM)

    cx0, cy0, cx1, cy1 = 840, 272, AW - MARG, 508
    d.rounded_rectangle((cx0, cy0, cx1, cy1), radius=8, fill=PANEL, outline=HAIR, width=2)
    d.rounded_rectangle((cx0 + 2, cy0 + 2, cx0 + 12, cy1 - 2), radius=6, fill=AMBER,
                        corners=(True, False, False, True))
    hx, hy = cx0 + 34, cy0 + 24
    d.text((hx, hy + 5), "08", font=plex(22), fill=DIM)
    hx += 62
    hx = chip(d, hx, hy, "PROSE", DIM, BAR, HAIR) + 12
    hx = chip(d, hx, hy, "DIRTY", AMBER, W_AMBER, AMBER) + 18
    d.text((hx, hy + 4), "—", font=plex(22), fill=INK)
    hx += 46
    warn_glyph(d, hx, hy + 6)
    hx += 30
    d.text((hx, hy + 8), "60-word sentence", font=plex(19), fill=AMBER)

    body = ("And he’s smart about it, too. He doesn’t overreach. "
            "He doesn’t claim the whole Bible is one long lie.")
    bf = literata(25)
    draw_par(d, wrap_words(d, body, bf, cx1 - cx0 - 76), cx0 + 34, cy0 + 86, 38, bf)

    d.text((840, 552), "the same collapse, at map scale:", font=plex(19), fill=DIM)
    for i, (col, lab) in enumerate([(GREEN, "approved"), (BLUE, "rendered"),
                                    (AMBER, "dirty"), (SIGNAL, "failed"), (HAIR, "new")]):
        x0 = 840 + i * 132
        d.rounded_rectangle((x0, 590, x0 + 40, 630), radius=4, fill=col)
        d.text((x0, 640), lab, font=plex(17), fill=DIM)

    d.text((MARG, 820),
           "Two hundred rows must stay scannable — one stripe and one word carry all five.",
           font=literata(28), fill=INK)
    foot(d, "simple_narrate — the block card", "spec §8 · style §2")
    im.save(path, optimize=True)


def fig_03(path):
    im = Image.new("RGB", (AW, AH), GROUND)
    d = ImageDraw.Draw(im)
    masthead(d, "simple_narrate · design by contract", "The transition with no handler.")

    bw, bh, by = 320, 108, 292
    lx, rx = 170, AW - 170 - bw
    f = archivo(34, 650)
    d.rounded_rectangle((lx, by, lx + bw, by + bh), radius=8, fill=W_GREEN,
                        outline=GREEN, width=3)
    d.text((lx + bw / 2 - d.textlength("APPROVED", font=f) / 2, by + bh / 2 - 21),
           "APPROVED", font=f, fill=GREEN)
    d.text((lx, by + bh + 18), "approved_take.hash  =  content_hash",
           font=plex(20), fill=DIM)
    d.rounded_rectangle((rx, by, rx + bw, by + bh), radius=8, fill=W_AMBER,
                        outline=AMBER, width=3)
    d.text((rx + bw / 2 - d.textlength("DIRTY", font=f) / 2, by + bh / 2 - 21),
           "DIRTY", font=f, fill=AMBER)
    cap = "approved_take.hash  /=  content_hash"
    d.text((rx + bw - d.textlength(cap, font=plex(20)), by + bh + 18),
           cap, font=plex(20), fill=DIM)

    ay = by + bh / 2
    ax0, ax1 = lx + bw + 26, rx - 26
    d.line((ax0, ay, ax1 - 6, ay), fill=SIGNAL, width=6)
    d.polygon([(ax1, ay), (ax1 - 24, ay - 14), (ax1 - 24, ay + 14)], fill=SIGNAL)
    top = "one keystroke — content_hash changed"
    d.text(((ax0 + ax1) / 2 - d.textlength(top, font=plex(22)) / 2, ay - 56),
           top, font=plex(22), fill=SIGNAL)
    bot = "no button · no handler · no event source"
    d.text(((ax0 + ax1) / 2 - d.textlength(bot, font=plex(22)) / 2, ay + 26),
           bot, font=plex(22), fill=DIM)

    px0, py0, px1, py1 = 170, 512, AW - 170, 768
    d.rounded_rectangle((px0, py0, px1, py1), radius=6, fill=PANEL, outline=HAIR, width=2)
    d.rectangle((px0 + 2, py0 + 2, px0 + 8, py1 - 2), fill=BLUE)
    cf = plex(24)
    cy, cx, lh = py0 + 40, px0 + 44, 46
    for line in [
        [("invariant", BLUE)],
        [("    approval_is_definitional:", INK)],
        [("        is_approved = (", INK), ("attached", BLUE), (" approved_take ", INK),
         ("as", BLUE), (" t", INK)],
        [("                        ", INK), ("and then", BLUE),
         (" t.hash.same_string (content_hash))", INK)],
    ]:
        x = cx
        for seg, col in line:
            d.text((x, cy), seg, font=cf, fill=col)
            x += d.textlength(seg, font=cf)
        cy += lh

    d.text((MARG, 812),
           "Edit one character and the block un-approves itself — "
           "approval was never an independent fact.",
           font=literata(28), fill=INK)
    foot(d, "simple_narrate — approval_is_definitional", "spec §18.1")
    im.save(path, optimize=True)


FIG04_PAR = ("And he’s smart about it, too. He doesn’t overreach. He doesn’t "
             "claim the whole Bible is one long lie. He does the thing that actually works "
             "on thoughtful people, which is to say: I’m not asking you to distrust the text.")


def fig_04(path):
    im = Image.new("RGB", (AW, AH), GROUND)
    d = ImageDraw.Draw(im)
    masthead(d, "simple_narrate · split preview",
             "You cannot mis-select what you never select.")

    bf = literata(25)
    lh, box_h, maxw = 40, 34, 1150
    lines = wrap_words(d, FIG04_PAR, bf, maxw)
    n_words = sum(len(l) for l in lines)

    # Panel A -- the rejected interaction
    ax0, ay0, ax1, ay1 = 110, 240, AW - 110, 466
    d.rounded_rectangle((ax0, ay0, ax1, ay1), radius=6, fill=PANEL, outline=HAIR, width=2)
    d.text((ax0 + 30, ay0 + 16), "you draw the selection", font=plex(20), fill=DIM)
    w = tracked_w(d, "REJECTED", plex(19), 2) + 24
    chip(d, ax1 - 24 - w, ay0 + 10, "REJECTED", SIGNAL, W_SIG, SIGNAL)

    tx, ty = ax0 + 30, ay0 + 64
    sel_end = n_words - 6                      # stops six words short of the end
    for bx in range_boxes(d, lines, bf, tx, ty, lh, box_h, 0, sel_end):
        d.rectangle(bx, fill=W_BLUE)
    draw_par(d, lines, tx, ty, lh, bf)
    stop = range_boxes(d, lines, bf, tx, ty, lh, box_h, sel_end - 1, sel_end)[0]
    sx, sy = stop[2], stop[3]
    note_y = ty + len(lines) * lh + 2             # clear of every text line
    d.line((sx, sy, sx, note_y + 10), fill=SIGNAL, width=3)
    note = "stopped six words short — the split lands here, silently"
    nw = d.textlength(note, font=plex(19))
    nx = sx + 14 if sx + 14 + nw < ax1 - 24 else sx - 14 - nw
    d.text((nx, note_y), note, font=plex(19), fill=SIGNAL)

    # Panel B -- the shipped interaction
    bx0, by0, bx1, by1 = 110, 512, AW - 110, 792
    d.rounded_rectangle((bx0, by0, bx1, by1), radius=6, fill=PANEL, outline=HAIR, width=2)
    d.text((bx0 + 30, by0 + 16), "you place a caret — the tool draws the boundary",
           font=plex(20), fill=DIM)
    w = tracked_w(d, "SHIPPED", plex(19), 2) + 24
    chip(d, bx1 - 24 - w, by0 + 10, "SHIPPED", GREEN, W_GREEN, GREEN)

    ty2 = by0 + 64
    caret_at = 22
    for bx in range_boxes(d, lines, bf, tx, ty2, lh, box_h, 0, caret_at):
        d.rectangle(bx, fill=W_BLUE)
    for bx in range_boxes(d, lines, bf, tx, ty2, lh, box_h, caret_at, n_words):
        d.rectangle(bx, fill=W_AMBER)
    draw_par(d, lines, tx, ty2, lh, bf)
    cbox = range_boxes(d, lines, bf, tx, ty2, lh, box_h, caret_at, caret_at + 1)[0]
    d.rectangle((cbox[0] - 2, cbox[1] - 2, cbox[0] + 1, cbox[3] + 2), fill=SIGNAL)

    ky = by1 - 54
    d.rectangle((bx0 + 30, ky, bx0 + 52, ky + 22), fill=W_BLUE)
    d.text((bx0 + 62, ky - 1), "everything above the caret", font=plex(19), fill=DIM)
    d.rectangle((bx0 + 430, ky, bx0 + 452, ky + 22), fill=W_AMBER)
    d.text((bx0 + 462, ky - 1), "everything below — drawn to the exact ends",
           font=plex(19), fill=DIM)

    d.text((MARG, 828),
           "The caret is the input; the highlight is the tool’s answer — "
           "there is no selection to get wrong.",
           font=literata(28), fill=INK)
    foot(d, "simple_narrate — split preview",
         "spec §8.4 · splits_mid_sentence is a query")
    im.save(path, optimize=True)


ARG_FIGURES = [
    ("02-one-stripe-one-chip", fig_02),
    ("03-transition-no-button", fig_03),
    ("04-caret-not-selection", fig_04),
]


def main():
    wanted = sys.argv[1:]
    browser = find_browser()
    print(f"Renderer: {browser}")
    print(f"Scale: {SCALE}x   Fonts: vendored (src/_fonts)")
    print("\n--- FIGURES: screenshots (Edge) ---")
    for slug, w, h in FIGURES:
        if wanted and not any(slug.startswith(a) for a in wanted):
            continue
        if not os.path.exists(os.path.join(SRC, f"fig-{slug}.html")):
            print(f"  skip   {slug} (no source)")
            continue
        render(browser, slug, w, h)
    print("\n--- FIGURES: argument graphics (Pillow) ---")
    for slug, fn in ARG_FIGURES:
        if wanted and not any(slug.startswith(a) for a in wanted):
            continue
        out = os.path.join(HERE, f"{slug}.png")
        fn(out)
        print(f"  ok     {slug}.png  {AW}x{AH}  {os.path.getsize(out) / 1024:.0f} KB")
    fails = contrast_report()
    sys.exit(1 if fails else 0)


if __name__ == "__main__":
    main()
