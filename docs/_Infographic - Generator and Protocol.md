# simple_narrate — Figure Generator & Protocol

*Created 2026-08-21. Follows the Substack essay production protocol §VIII, with one
deliberate deviation recorded below.*

> **The script is the durable artifact, not the PNGs.** Re-render from
> `_artwork/render.py`. If the figures and the specification ever disagree, the
> specification wins and the figures get re-rendered.

---

## The deviation, stated plainly

The essay protocol composes figures in **Pillow**: hand-placed coordinates, seeded
grain, vendored fonts, contrast computed and printed. That is correct for an
argument graphic — a door ajar, a struck tally, a hero number.

These figures are **not argument graphics. They are screenshots of a proposed
user interface**, and the subject is therefore a *layout*: four block cards whose
prose must wrap, a forty-four cell status grid, a variable-width toolbar, a takes
table. In Pillow every one of those is hand-computed x/y plus manual text
measurement and line breaking. CSS is a layout engine and does it for free.

**So the renderer is headless Edge rather than Pillow.** Everything else in the
protocol is carried over unchanged, and one thing is carried over *because* it
would otherwise have been lost:

| Protocol requirement | How it is honoured here |
|---|---|
| The script survives, not the PNGs | `_artwork/render.py` + `_artwork/src/*.html` |
| Fonts fetched, never assumed | **Vendored** in `src/_fonts/`. No CDN at render time. |
| Deterministic | No randomness. Same source → same PNG. |
| Contrast computed and printed | `render.py` prints a WCAG report. **Any FAIL is a blocker.** |
| Recessive rules, hairlines | 1 px in `--app-line` |
| Text wears text ink | Accent colours carry state, never captions |

⚠ **Both kinds now live in the one script.** Screenshots (figure 01) render
through headless Edge because their subject is a layout; argument graphics
(figures 02–04) are Pillow-composed because their subject is a claim — one
argument made visible per figure, per the essay-series principle. They share the
token palette and the vendored fonts, and both pass through the same contrast
gate. One deliberate difference from the essay series: **no film grain** — that
texture belonged to the night-corridor world; this subject's world is clean
drafting paper, and flat is the identity.

---

## Design brief

**Subject world.** A production tool, not a consumer app. Cool drafting neutrals,
a white working surface, and colour used only where it carries state. The window
should look like something you would leave open for three hours.

**The one hard rule this set enforces:** *state is compound but must read as one
thing.* A block is simultaneously dirty-or-clean, rendered-or-not,
approved-or-not, gated-or-not, warned-or-not. Five status icons across two
hundred rows is noise. So: **one severity stripe on the left edge, plus one
chip.** Everything else lives in the detail panel for the selected block only.

**Colour assignments** — these are load-bearing and must not drift between
figures:

| Token | Hex | Means, and only this |
|---|---|---|
| green | `#1D6B52` | approved |
| blue | `#1F5FA8` | rendered / interactive |
| amber | `#8A5A0B` | dirty, and warnings |
| signal | `#AF3A22` | failed, and the caret |
| line | `#D3DAE3` | new / inert |

⚠ **A known compromise.** The essay protocol says *categories separate by shape,
never by hue* — and the map rail separates five block states by hue alone. It is
accepted here because the rail is a **status readout with a printed legend
beside it**, not a categorical comparison, and because the states also carry
shape elsewhere (the stripe position and the chip word). It would be wrong in a
chart. It is defensible in a status grid. Recorded so the exception stays
deliberate.

---

## Deliverables

| File | Kind | The one argument it makes |
|---|---|---|
| `01-editor-window.png` | screenshot (Edge) | The whole surface at scale. Four blocks in four states, the map rail carrying the rest of the essay, and Publish naming its own blocker rather than greying out. |
| `02-one-stripe-one-chip.png` | argument (Pillow) | Five state facts collapse to a stripe and a word — why two hundred rows stay scannable. |
| `03-transition-no-button.png` | argument (Pillow) | `approved → dirty` has no handler. It is the definitional invariant firing, typeset beside the arrow it drives. |
| `04-caret-not-selection.png` | argument (Pillow) | The caret is the input; the highlight is the tool's output. The mis-selection failure cannot occur because no selection is ever made. |

---

## Regeneration protocol

```bash
cd docs/_artwork
python3 render.py            # all figures
python3 render.py 01         # one figure
```

1. Requires Python 3 with Pillow, and Microsoft Edge (or Chrome — see `EDGE_ALTS`).
2. PNGs land beside the script at 2× device scale, auto-cropped to content.
3. **The contrast report is a gate.** A non-zero exit means at least one pair
   failed; fix the palette before shipping.
4. **Currency:** these figures display specification behaviour. If a decision in
   `specs/spec.md` changes what a control does, re-render — and if the figure
   cannot show the new behaviour, the figure is wrong, not the spec.

---

## Render log

**2026-08-21 — first render.** The contrast gate caught a real defect on its first
run: the two split-preview tints scored **1.02:1 against each other.** They read
as clearly different to the eye because they differ in *hue*, but they were
almost identical in *luminance* — meaning the split preview would have been
invisible in greyscale or to a reader with colour-vision deficiency. Retuned to
`#C7DAF1` / `#FAF1DD`, now 1.27:1.

That is the whole case for computing contrast instead of eyeballing it, and it
happened on figure one.

**2026-08-21 — figures 02–04 (Pillow argument graphics).** Second defect caught
by looking rather than trusting: variable-font axes were passed **by guessed
position** (`[wdth, wght]`), and every Archivo headline rendered Thin-Expanded —
the axes had landed in the wrong slots. Fixed by matching values to the font's
own `fvar` table **by axis name**, never by position; `masthead` also gained
shrink-to-fit so a true-bold headline can never overrun the margin. Rule for
this file: after any font change, *view* the render — a clean exit code says
nothing about weight.
