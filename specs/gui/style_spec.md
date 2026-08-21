# simple_narrate — GUI Style Specification

*Derived from `docs/_artwork/01-editor-window.png`. Draft 1, 2026-08-21.*

> **Verdict: `simple_vision` can produce that look, and most of the parts already
> exist.** The gap is not capability. It is that nobody has written the token
> values down for this application — `SV_TOKENS` currently ships Material Design 3
> defaults.

---

## 1. What was verified, by reading it

| Capability | Where | State |
|---|---|---|
| Design tokens — semantic colours, typography, spacing, borders, animation | `simple_vision/src/styling/sv_tokens.e` (436 lines) | ★ exists, **seeded with Material Design 3** (`primary = #6750A4`, `Segoe UI`, `Consolas`) |
| Theming | `src/styling/sv_theme.e` (714 lines) | exists |
| Antialiased vector drawing — colour, shapes, **paths**, gradients, text, transforms | `src/graphics/sv_cairo_canvas.e` (648 lines), fluent API | exists |
| Rounded rectangles | `sv_cairo_canvas.rounded_rect (x, y, w, h, radius)` line 220 | ★ exists |
| Audio waveform widget | `src/graphics/sv_waveform.e` (490 lines) | ★ exists — unplanned for, immediately useful |
| Every widget the mockup uses | `src/widgets/` | ★ all present — see §3 |
| Embedded WebView2 | `simple_browser/src/core/webview_engine.e` (463 lines, inline C, `c_webview_navigate`) | real, and the **fallback route** — §6 |

⚠ **Not found:** any shadow primitive in the Cairo canvas. The mockup's only real
shadow is on the outer window frame, which the OS draws anyway. The selection ring
is a 2 px solid outline and needs nothing special.

---

## 2. Token overrides

These replace the Material Design 3 defaults. **Every value is carried over from
the rendered figure, where it passed a computed WCAG check** (see
`docs/_artwork/render.py`); do not retune by eye.

```eiffel
    -- Surfaces
    app_background      #E9ECF1     -- the working ground
    surface             #FFFFFF     -- block cards, detail cards
    surface_variant     #F5F7FA     -- toolbar, rails, status bar
    outline             #D3DAE3     -- every hairline, 1 px
    on_surface          #1A2029     -- primary text          16.4:1 on surface
    on_surface_variant  #5A6573     -- secondary text         5.9:1 on surface

    -- State. Each colour means ONE thing and must not drift.
    state_approved      #1D6B52     -- green
    state_rendered      #1F5FA8     -- blue, doubles as interactive
    state_dirty         #8A5A0B     -- amber, doubles as warning
    state_failed        #AF3A22     -- signal, doubles as the caret
    state_new           #D3DAE3     -- inert

    -- Washes: chip fills and the split-preview tints
    wash_approved       #E0F0E9
    wash_rendered       #C7DAF1
    wash_dirty          #FAF1DD
    wash_failed         #F8E7E2
```

⚠ **`wash_rendered` and `wash_dirty` are load-bearing as a *pair*.** They are the
split-preview tints, and they must differ in **luminance**, not merely hue —
1.27:1 as specified. The first draft used values that were obviously different to
the eye and measured **1.02:1**: identical in greyscale, invisible to a reader
with colour-vision deficiency. Changing either value re-opens that defect.

### Typography

```eiffel
    font_family         "Archivo"          -- UI chrome, labels, buttons
    font_family_text    "Literata"         -- block prose ONLY
    font_family_mono    "IBM Plex Mono"    -- all numbers, chips, status, seeds
```

★ **Three families, and the split is semantic rather than decorative.** Mono is
not a style choice — it marks *machine-produced values*: fidelity scores, seeds,
word counts, engine errors, timings. A serif marks *the author's own prose*.
Sans marks *the tool speaking*. A reader can tell at a glance whose voice a piece
of text is in.

⚠ **Deployment gap.** `SV_TOKENS` defaults to Segoe UI and Consolas because they
are always present. These three are not. Either the installer places them, or the
theme falls back — and the fallback must be specified, not discovered:
`Archivo → Segoe UI`, `Literata → Georgia`, `IBM Plex Mono → Consolas`.

### Metrics

```eiffel
    radius_card          3        -- block cards, detail cards, chips
    radius_window        5
    stripe_width         4        -- the block severity stripe
    hairline             1
    gap_block            9        -- between block cards
    pad_card            "9 11"    -- block card interior
    pad_panel           11        -- detail panel
    font_size_chip       9.5
    font_size_body      12
    font_size_metric    22        -- the fidelity figure
```

---

## 3. Widget mapping

**Every element in the figure maps to an existing `sv_*` class.** Nothing new is
required except one custom widget (§4).

| Figure element | Class |
|---|---|
| Window shell | `SV_WIDGET` root + `SV_SPLITTER` |
| Top bar | `SV_TOOLBAR`, `SV_TOOLBAR_BUTTON`, `SV_SEPARATOR`, `SV_SPACER` |
| Publish button | `SV_BUTTON` + a mono label bound to `publish_blocker_text` |
| Map rail | `SV_CAIRO_CANVAS` — 44 `rounded_rect` fills, hit-tested for click-to-scroll |
| Block list | `SV_SCROLL` containing `SV_CARD` per block |
| Chips | `SV_CARD` (radius 3) or canvas-drawn — canvas is cheaper at 200 rows |
| Block prose | ★ **`SV_BLOCK_EDITOR` — the one custom widget, §4** |
| Block actions | `SV_BUTTON`, `SV_DROPDOWN` |
| Detail panel | `SV_CARD` × 4 |
| Takes table | `SV_DATA_GRID` |
| Exaggeration | `SV_SLIDER` |
| Seed | `SV_SPIN_BOX` |
| Per-block progress | `SV_PROGRESS_BAR` |
| Status strip | `SV_STATUSBAR`, `SV_PROGRESS_BAR` |
| Mid-sentence warning | `SV_DIALOG` |
| ★ Audio scrub *(new, unplanned)* | `SV_WAVEFORM` |

★ **`SV_WAVEFORM` was not in the original design and should be.** A block's
render is a few seconds of audio; showing its waveform makes the prosody
measurements *visible* — a 22-second unbroken run is a solid unbroken block of
ink, and the boundary silence the gate measures is literally a gap you can see.
It turns §17.4's numbers into a picture at no design cost.

---

## 4. `SV_BLOCK_EDITOR` — the one thing that must be built

Everything else composes. This does not, because it needs four behaviours at
once that no stock text widget provides:

1. word-wrapped prose at a given width
2. **per-run background tint** — the two-tone split preview
3. inline emphasis rendered as bold, from `!marker!` syntax
4. a caret whose character offset is readable by the host

Drawn on `SV_CAIRO_CANVAS`. Sketch of the contract:

```eiffel
class SV_BLOCK_EDITOR

feature -- Access
    text: STRING_32
    caret_offset: INTEGER
    preview_split: BOOLEAN        -- tint above and below the caret

feature -- Measurement
    offset_at (a_x, a_y: INTEGER): INTEGER
            -- Character offset under a point.
        ensure
            in_range: Result >= 0 and Result <= text.count

    is_sentence_boundary (a_offset: INTEGER): BOOLEAN
            -- ★ A QUERY. Never a precondition on split - see spec 18.4.

invariant
    caret_in_range:   caret_offset >= 0 and caret_offset <= text.count
    tint_pair_legible: wash_rendered.luminance_ratio (wash_dirty) >= 1.15
```

⚠ `tint_pair_legible` puts §2's accessibility finding where it cannot be
undone by a later palette edit. It is the contract equivalent of the render
script's contrast gate.

⚠ **Realistic cost.** Text layout is the expensive part of any GUI toolkit, and
this widget is a small text engine. It is the single largest risk in Phase 2, and
it is the reason §6 keeps a fallback.

---

## 5. What the tokens buy beyond looks

Replacing the MD3 defaults is not a cosmetic act. Three of the design's
*specification* commitments become expressible only once the tokens exist:

- **One colour, one meaning.** `state_dirty` is the block stripe, the chip, the
  map cell, and the warning text. A block that goes stale changes in four places
  from one token.
- **The map rail is the token table rendered.** Its legend is generated from the
  tokens, so a legend can never drift from the fills.
- **Contrast is a build-time fact.** The values in §2 arrived with computed
  ratios attached. `SV_COLOR` should carry a `luminance_ratio` query so the
  invariant in §4 can be stated at all.

---

## 6. The fallback route, and why it is not the recommendation

`simple_browser` really does embed WebView2. Pointing it at the HTML in
`docs/_artwork/src/` would be **pixel-identical to the figure**, because it is
the same rendering engine that produced it, and it would make §4 disappear
entirely — the browser already has a text engine.

**It is still not the recommendation**, for three reasons:

1. It trades one custom widget for a whole IPC boundary between Eiffel state and
   a JavaScript view — more total work, and the seam is permanent.
2. It puts the UI outside Design by Contract. The invariants in §4 would live in
   JavaScript or nowhere.
3. `simple_ocr_capture` advertises *"a single executable — no runtime, no
   redistributable, no Python."* A WebView2 view layer is a quiet retreat from
   the property the ecosystem sells.

★ **Reconsider only if `SV_BLOCK_EDITOR` proves harder than a week.** That is the
decision point, and it should be made after a spike on the widget, not now.
