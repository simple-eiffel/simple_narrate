# simple_narrate — MARKS AS SPANS, NOT NOTATION

**An amendment to [`spec-studio.md`](spec-studio.md) §S6.** Written
2026-09-06 after Larry's direction, in his words: *"adding characters to text
(e.g. `_word_` or `^word` …) might be limited. And one may simply want to
select part of the text … and apply a 'speaking function' to the selected text
from a palette of speaking functions."*

Status: the toolkit side is **built and green** (`simple_widgets` 0.8.0,
327/327). The narrate side is specification.

---

## M1. What changes

§S6 wrote the marks *into* the block text as ASCII — `|`, `||`, `{slow} …
{/slow}`, `word{=koh-DESH}`, `_word_` — and stripped them before synthesis.
That notation stays valid as an **import and export format** (a script a human
reads), but it is no longer the **editing surface**.

The editing surface is a **selection plus a palette**:

1. The author selects any range — characters, part of a word, a word, a phrase.
2. They pick a *speaking function* from the palette (the legend view).
3. The block's data-behind records a **span**: range, function, optional
   detail (the respelling, the pause length), through `SW_MARKED_TEXT`.
4. The span **follows its words** through every later edit — typing inside it
   grows it, deleting across it trims it, undo restores it. Nothing in the text
   itself changes.
5. The compiler that builds segments for the engine reads the spans, not the
   text.

## M2. The speaking functions are legend reasons

| function (§S6 mark) | reason key | detail (annotation) | executable? | look (default) |
|---|---|---|---|---|
| short beat `\|` | `beat` | — | ✅ 0.25 s | violet, box 1 |
| breath `\|\|` | `breath` | — | ✅ 0.5 s | violet, box 2 |
| long hold `\|\|\|` | `hold` | — | ✅ 1.0 s | violet, box 3 |
| exact pause `[[1.4]]` | `pause` | seconds | ✅ | violet, box 1, badge `1.4` |
| `{slow}` | `slow` | — | ✅ length_scale | teal, wash, italic |
| `{fast}` | `fast` | — | ✅ | cyan, wash, italic |
| `{soft}` | `soft` | — | ⚠ gain + rate | blue, wash |
| `word{=koh-DESH}` | `pronounce` | the respelling | ✅ **highest value** | red, outline 1, badge `P` |
| `_word_` | `emphasis` | — | ❌ advisory | amber, colorized bold |
| `(warmly)` | `direction` | the direction | ❌ advisory | grey, italic, badge `»` |

The **advisory** functions keep their §S6.3 honesty by *look*: the legend gives
them a distinct hue class and the label says "does not change synthesized
audio". The application can re-theme them when the block's slot becomes
`recorded` (where a human reads them), because the legend owns the look and
the spans do not.

A pause is a span over the *character after which* it falls (or the whitespace);
its position is what the compiler needs, its length is the annotation.

## M3. What the toolkit provides (verified by building it)

| need | class | note |
|---|---|---|
| remember the spans | `SW_MARKED_TEXT` / `SW_MARK_SPAN` | ids, reasons, annotation, edit reconciliation, `code` / `make_from_code` — the session file stores `code` per block |
| the meaning | `SW_MARK_LEGEND` | reasons → look, label, badge; re-theme by app state |
| the look | `SW_MARK`, `SW_MARK_PALETTE` | 12 hues, WCAG-held on light and dark |
| the painting | `SW_MARK_PAINTER` | wash / box / outline / colour / bold / italic; size floors so small type is not cluttered |
| the reference | `SW_MARK_LEGEND_VIEW` | the palette the author picks from; `on_pick` → apply to the selection |
| the editors | `SW_TEXT_BOX.marks`, `SW_PARAGRAPH_LIST.marks_of` | the block thread and its in-place editor share one object per block |

## M4. Consequences for the rest of the spec

- **`NARRATE_BLOCK` gains `marks_code: STRING_32`** — the span codec, stored in
  the session TOML beside `text`. The content hash (§8.1) covers it: a new
  span on a block is a new render, exactly as an inline mark was.
- **The segment compiler** (§8, §S6.2) takes `(text, marks)` and emits
  segments and silences from the spans. Inline notation in imported text is
  converted to spans at import (§7), once, and the text is cleaned.
- **Export** (`script.spoken.txt`) writes the §S6 notation back *from* the
  spans, so a human reading script still carries the marks.
- **Split at caret** (§8.4) splits the marked text too: `SW_MARKED_TEXT` gains
  nothing new — the host builds two texts and two codecs from the spans on
  either side (a span across the cut is trimmed into both halves).
- **Prosody capture** (§S5) *emits spans*, not characters. This is a better fit
  than the original: capture writes `slow` / `beat` spans with confidence in
  the annotation, and the author deletes the ones that are wrong from the
  legend's colour, not by editing notation.
- **The size floor.** At the Studio's body size the full look applies; the map
  rail and any small preview fall under `min_effect_size` and show wash and
  colour only — by the painter's policy, not by special-casing.

## M5. Open

1. Whether `beat` / `breath` / `hold` remain three reasons or one `pause` with
   a default length per badge. Recommendation: one `pause`, three presets in
   the palette — fewer hues spent.
2. Whether the legend view lives in the west dock with the palette (F2) or
   floats near the selection. Recommendation: west dock; a floating palette is
   a later refinement.
