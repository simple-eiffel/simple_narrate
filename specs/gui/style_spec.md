# simple_narrate — GUI Style Specification

*Derived from `docs/_artwork/01-editor-window.png` (the reference render).
Draft 2, 2026-08-21 — the verdict below **corrects draft 1**, which had verified
the widget *inventory* but not the widget *rendering path*.*

> **Verdict: the reference look is reachable — but not by theming the stock
> widgets.** Draft 1 claimed the gap was "not capability." Reading one line
> deeper disproved that: `sv_*` widgets **wrap native `EV_*` controls**
> (`sv_button.e:2` — *"wraps EV_BUTTON"*; `sv_card.e:2` — *"wraps EV_FRAME"*,
> whose styles are the Win32 raised/lowered/etched frames). Tokens can recolour
> a native control; they cannot give it flat hairline chrome, a 4 px severity
> stripe, or a 3 px radius.
>
> The route is the *other* thing `simple_vision` ships: `SV_CAIRO_CANVAS`. The
> reading surface — where the eyes live — gets **drawn**; the periphery stays
> native in v1. And the foundation under that route is **`simple_cairo`,
> expanded first** (§7, Layer 0) — decided 2026-08-21: a fuller Cairo wrapper is
> a welcome end in itself if it gives Eiffel a more modern GUI capacity.

---

## 1. What was verified, by reading it

| Capability | Where | State |
|---|---|---|
| Design tokens — semantic colours, typography, spacing, borders, animation | `simple_vision/src/styling/sv_tokens.e` (436 lines) | ★ exists, **seeded with Material Design 3** (`primary = #6750A4`, `Segoe UI`, `Consolas`) |
| Theming | `src/styling/sv_theme.e` (714 lines) | exists |
| Antialiased vector drawing — colour, shapes, **paths**, gradients, text, transforms | `src/graphics/sv_cairo_canvas.e` (648 lines), fluent API | exists |
| Rounded rectangles | `sv_cairo_canvas.rounded_rect (x, y, w, h, radius)` line 220 | ★ exists |
| Audio waveform widget | `src/graphics/sv_waveform.e` (490 lines) | ★ exists — unplanned for, immediately useful |
| Every widget the mockup uses | `src/widgets/` | present, **but as native `EV_*` wraps** — recolourable, not re-chromable (§7) |
| Canvas → screen path | `sv_cairo_canvas.e` renders to an offscreen surface, then `copy_surface_to_drawing_area` blits into an `EV_DRAWING_AREA` | verified — and reusable for row pixmaps (§7, Layer 1) |
| Takes table substrate | `sv_data_grid.e:2` — *"wraps EV_GRID"*, `EV_GRID_COLUMN` / `EV_GRID_LABEL_ITEM` in use | the EV_GRID binding already exists in-tree |
| **Text measurement** | — | ⚠ **absent.** `simple_cairo` wraps `select_font` / `set_font_size` / `show_text` only; `grep extents` returns nothing. **No wrapping layout can be written without it.** §7, Layer 0. |
| Private font loading | — | ⚠ absent — no `AddFontResource*` anywhere in `simple_vision` or `simple_cairo`. §7, Layer 1. |

⚠ **Also not found:** any shadow primitive in the Cairo canvas. The mockup's only
real shadow is on the outer window frame, which the OS draws anyway. The
selection ring is a 2 px solid outline and needs nothing special.

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

## 3. Widget mapping — two tiers

*(Rewritten in draft 2. Draft 1 mapped chips to `SV_CARD` and block cards to
`SV_CARD`-in-`SV_SCROLL`; both are `EV_FRAME` wraps and cannot take the chrome.)*

**Tier 1 — drawn (carries the visual identity).** The entire centre pane is one
custom-rendered surface, not a tree of native controls. That is not a
compromise; it is how editors are built — 200 block cards as native widget
trees would be ~2,400 live Win32 handles.

| Element | Substrate |
|---|---|
| Block list — cards, stripes, chips, heads | ★ `SV_BLOCK_LIST`: **`EV_GRID` + drawable rows**, one row per block, each row's card rendered through Cairo and blitted (the `copy_surface_to_drawing_area` mechanism, reused). EV_GRID contributes scrolling, selection, and virtualisation for free — and it is the class already trusted in this shop. Fallback substrate: one `SV_CAIRO_CANVAS` with manual virtualisation. |
| Chips, severity stripes | draw calls inside the row render — **not widgets at all** |
| Block prose + split preview | ★ `SV_BLOCK_EDITOR` (§4) — the hard one |
| Map rail | `SV_CAIRO_CANVAS`, 44 `rounded_rect` fills + hit test |
| Audio scrub *(new, unplanned)* | `SV_WAVEFORM` |

**Tier 2 — native in v1 (accepts the Win32 look, for now).**

| Element | Class |
|---|---|
| Window shell, panes | `SV_WIDGET` root + `SV_SPLITTER` |
| Toolbar, buttons | `SV_TOOLBAR`, `SV_TOOLBAR_BUTTON`, `SV_BUTTON` |
| Publish + blocker text | `SV_BUTTON` + bound mono label |
| Takes table | `SV_DATA_GRID` (already EV_GRID) |
| Exaggeration / seed | `SV_SLIDER` / `SV_SPIN_BOX` |
| Progress, status strip | `SV_PROGRESS_BAR`, `SV_STATUSBAR` |
| Mid-sentence warning | `SV_DIALOG` |

⚠ **Honest statement of what v1 looks like:** the centre pane and map rail are
pixel-faithful to the reference render; the toolbar and detail panel are native
controls wearing the token colours. The identity concentrates where the eyes
spend their time. Re-chroming the periphery is a later, optional pass — and
becomes cheap once the drawn-widget vocabulary from Tier 1 exists.

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

⚠ **Hard dependency:** `text_extents` in `simple_cairo` (§7, Layer 0 — verified
absent). Word wrap is *measure, then place*; without measurement this widget
cannot be started, let alone finished.

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

---

## 7. Roadmap: the route to the reference render

Three layers, built bottom-up. Each layer is useful to the ecosystem on its own;
none exists only for simple_narrate.

### Layer 0 — expand `simple_cairo` first  ★ *decided 2026-08-21*

The direction, in Larry's words: *"the creation first of a simple_cairo that
takes full advantage of the Cairo facilities … just fine to me at the end of it
all if that is what gets us to Eiffel having a better / more-modern GUI
capacity."* This is ecosystem option 2 — extend into modernity — applied to the
foundation rather than the leaves.

**Scope statement (Larry, same day): *"A simple_cairo that I can use for
anything on a native Windows PC."*** General-purpose 2D, not a GUI-only
dependency: one API whose identical drawing calls paint a live window, write a
PNG, or lay out a PDF page — GUIs, report generators, chart renderers, image
pipelines. The narrate GUI is the forcing consumer, not the boundary of the
ambition.

⚠ **With the §8.3.1 sequencing rule attached:** the expansion is *driven by what
`SV_BLOCK_EDITOR` and `SV_BLOCK_LIST` demand*, with simple_narrate as the
forcing consumer. "Wrap all of Cairo" in the abstract is how `simple_voice`
happened. Wrap what the consumer proves it needs; the rest of Cairo joins when
something needs it.

What the consumer demands, in order:

| Addition | Why | Size |
|---|---|---|
| ★ `text_extents` / `font_extents` | **the blocker** — measure before wrap; also baseline/ascent for caret placement | ~30 lines each, inline C |
| font options: antialias mode, hinting | crisp text at 12 px — the difference between the reference render and a blurry cousin | ~30 lines |
| `clip` / `reset_clip` | partial redraw of a virtual list without repainting the world | ~20 lines |
| `push_group` / `pop_group_to_source` | flicker-free composite of a row before blitting | ~20 lines |
| dash patterns, line caps *(verify — "Line Properties" block may cover)* | focus rings, drop-target hints | small |

A few days of careful work with tests, and every future Eiffel GUI inherits it.

### Layer 1 — `simple_vision`: the drawn vocabulary

| Item | Notes | Size |
|---|---|---|
| `NARRATE_THEME` | the §2 token values over `SV_TOKENS`' MD3 defaults | hours |
| private font loading | `AddFontResourceExW (…, FR_PRIVATE)` at startup — the vendored TTFs become selectable by name through Cairo's Win32 font backend, no installer step. Lives in the theme layer; `simple_cairo` stays a pure Cairo wrapper. | ~30 lines inline C |
| hairline discipline | canvas helpers that snap 1 px rules to the half-pixel grid — the difference between crisp and smeared | ~20 lines |
| `SV_COLOR.luminance_ratio` | enables `tint_pair_legible` (§4) and a build-time contrast gate mirroring `render.py`'s | hours |
| `SV_BLOCK_LIST` | EV_GRID drawable rows + Cairo row renderer (§3 Tier 1) | days |
| ★ `SV_BLOCK_EDITOR` | §4 — the week-scale item, **unstartable until Layer 0 lands** | ~a week |

### Layer 2 — keep native, re-chrome later (or never)

Toolbar, buttons, slider, spin box, dialogs, status bar, takes table. Token
colours only in v1. Each becomes individually cheap to re-chrome once the Tier 1
vocabulary exists — and none of them is where the eyes live.

### The decision points, restated

1. **Layer 0 goes first** regardless — it is small, general, and everything
   above it waits on `text_extents`.
2. After Layer 0: **spike `SV_BLOCK_EDITOR` for one week.** If it lands, the
   route is proven end to end. If it does not, §6's WebView2 fallback is taken
   *for the view layer only*, and Layer 0 remains a clean ecosystem win either
   way.
3. Nothing in this roadmap blocks the narration engine (spec §15 Phase 1), which
   has no GUI at all. The two tracks can proceed independently.
