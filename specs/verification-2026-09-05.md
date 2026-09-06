# Verification pass — 2026-09-05

Closes the open rows in `HANDOFF-STUDIO.md` §5.2 and §5.3 and corrects three
stale claims. **Verified means someone read it** — every row below cites the
file and line that was read.

---

## 1. Correction: Eiffel HAS been written, and it was harvested

`HANDOFF-STUDIO.md` §1 said *"No Eiffel has been written for this."* That is
wrong, and the error matters because the code that exists is the ancestor of
the toolkit the Studio will be built on.

| what | where | evidence |
|---|---|---|
| **`NARRATE_GUI`** — 1,584 lines. Pure Win32 pump + `simple_cairo`. Caret, selection (click, drag, double-click, shift+arrows), live split-preview tint at the caret, Split Here / Approve / Up / Down on a dynamic block model | `narrate_gui/narrate_gui.e` | commit `3f2c6cf` 2026-08-21 20:16 *"The block editor lives"* |
| **`NARRATE_BLOCK`** — 110 lines. ordinal, kind (HEADING/PROSE/SEPARATOR), state (APPROVED/RENDERED/DIRTY/FAILED/NEW), fidelity, warn, text; `mark_dirty` | `narrate_gui/narrate_block.e` | same commit |
| **`SW_TEXT_BOX`** in `simple_widgets` — *"Harvested from the narrate editor, where it was proven against live and synthetic input."* | `simple_widgets/src/sw_text_box.e:3-8` | first commit `ef8da9f` 2026-08-21 20:38, **22 minutes after** the narrate editor landed |

So the narrate editor's text engine already lives in `simple_widgets`, with
word wrap, caret, selection, clipboard, spellcheck, and undo/redo added since.
**Phase S2 does not port `NARRATE_GUI`; it rebuilds the shell on
`simple_widgets`, whose text box IS the narrate engine.** The block model,
state vocabulary and split-tint behaviour in `NARRATE_GUI` remain the
reference for what the Studio's block list must do.

`simple_narrate.ecf` still targets the old shell (depends on `simple_cairo`
only, root `NARRATE_GUI`). It will need `simple_widgets` + `simple_shaping`
added for Phase S2.

---

## 2. §5.2 — Does the shaping layer expose cluster-to-byte mapping?

**Yes at the data level, and the boundary walk is already written — but it
lives in a read-only widget, not in the editor.** Three facts:

### 2.1 The data is there (simple_shaping)

`GLYPH_RUN` publishes, per run:

- `cluster_map: ARRAY [INTEGER]` — *"Source character -> first glyph of its
  cluster (1-based)"* (`src/pipeline/shaped_item.e:82-83`; `glyph_run.e:401`)
- `x_positions: ARRAY [REAL_64]` — per-glyph x, run-relative (`glyph_run.e:440`)
- `source_start`, `source_count`, `is_rtl` (`shaped_run.e:308-334`)

The contract `cluster_per_source_char: a_cluster_map.count = a_source_count`
(`glyph_run.e:390`) means every source character has an entry. Indices are
**STRING_32 character indices**, not bytes — better than the question asked,
since Eiffel's caret is a character index too.

`SHAPED_LINE` **reserves but does not compile** the convenience features
`character_index_at_x` and `x_at_character_index` (FR-013,
`shaped_line.e:267-272`).

### 2.2 The walk is written (simple_widgets, read-only)

`SW_CHAT_THREAD` implements the hit-test itself over the published runs:

- `shaped_offset_in_line` (`sw_chat_thread.e:1814-1866`) — walks every run in
  visual order, every cluster boundary, picks the nearest x
- `run_boundary_x` / `run_boundary_offset` (`:1868-1906`) — RTL handled by
  direction: *"in a right-to-left run the boundary at a cluster's LEFT edge is
  the caret AFTER that character"*
- `cluster_x` (`:1908-1920`) — `cluster_map` → `x_positions`

`SW_SHAPED_TEXT` (`sw_shaped_text.e`) carries a second copy for one-line
chrome: `character_span (layout, index): [left, width]` (`:155`) — the
inverse direction, caret placement by source index.

This is selection and copy in a chat bubble (0.6.0). It is **not editing**.

### 2.3 The editor is unshaped

`SW_TEXT_BOX` never references the shaping kit (grep `shap` over
`sw_text_box.e`: no hits in code). Its layout is cairo toy text advances
(`lay_x`, `lay_adv`, `lay_line`) — the same arrays `NARRATE_GUI` uses.
**So an editable Hebrew run does not exist anywhere in the ecosystem yet.**

### 2.4 What this means for Phase S2

| option | cost | verdict |
|---|---|---|
| **A. Shaped `SW_TEXT_BOX`** — give the text box a shaped layout path and lift `shaped_offset_in_line` / `character_span` into a shared helper both widgets call | one widgets cycle; the two boundary walks already exist and would be de-duplicated | **recommended.** The hard part (RTL cluster arithmetic) is done and tested in the thread; the missing part is wiring, not invention |
| B. `spec-studio.md` §S7.1 fallback — edit as plain LTR source, shaped view alongside | zero | ships today; Hebrew inside a block edits as a left-to-right string of code points, which is tolerable for short quoted words |

Recommendation: **build S2 on option B first** (it is what `SW_TEXT_BOX` does
now) and queue option A as a `simple_widgets` feature. Nothing in the block
model depends on which one wins.

---

## 3. §5.3 — Ecosystem rows

### 3.1 `simple_onnx` — in-process TTS: possible in principle, not for Kokoro/Chatterbox as shipped

Read: `README.md`, `src/simple_onnx.e`, `src/onnx_session.e`. Production,
v1.0.0, ONNX Runtime C API via inline C, CPU/CUDA/TensorRT providers,
`ONNX_TOKENIZER` exists.

The binding is sound. The obstacle is the models: Kokoro-82M's ONNX export
needs a phonemizer in front of it (espeak-ng — the prototype's `EspeakFallback`
lesson), and Chatterbox is a PyTorch pipeline, not a single graph. Piper is the
one candidate that is genuinely "one ONNX file + phonemes", and the prototype
rejected Piper on articulation.

**Verdict:** keep the HTTP hop (`spec.md` §12 `LOCAL_TTS_ENGINE`) for Phase 1.
`simple_onnx` is a real option for a later `ONNX_TTS_ENGINE` behind the same
`TTS_ENGINE` boundary, and costs nothing to defer.

### 3.2 `simple_ffmpeg` — loudness normalisation: absent as a feature, reachable today

Read: `README.md`, `src/simple_ffmpeg.e`, `src/ffmpeg_options.e`,
`src/cli/ffmpeg_cli.e`.

- grep `loudnorm|lufs|ebur128|loudness|concat|silence|normali` over `src/`:
  **zero hits.** Confirms `spec.md` §13 and extends it — no loudness
  normalisation, no concat, no silence.
- `FFMPEG_OPTIONS` has codec/bitrate/rate/channels only — no filter slot.
- ★ **`FFMPEG_CLI.transcode_with_args (input, output, raw_args)`**
  (`ffmpeg_cli.e:157-183`) passes raw arguments through.
  `-af loudnorm=I=-16:TP=-1.5:LRA=11` works through it **today**, without
  touching the library.

**Verdict:** §S3.4's target (−16 LUFS, −1.5 dBTP) is reachable through the
passthrough for Phase 1. Add named features when extending for concat and
silence (`spec.md` §14.1 already owes those two): `normalize_loudness (input,
output, lufs, true_peak)` alongside `concat_demux` and `generate_silence`.
Three small features, one PR.

### 3.3 Undo / redo — the claim "absent from all libraries" is stale

`SW_TEXT_BOX` has it: `can_undo`, `can_redo`, `undo`, `redo`,
snapshot `undo_stack` / `redo_stack` with typing runs coalesced, blocks (paste,
cut, drop) standing alone, Ctrl+Z / Ctrl+Y (`sw_text_box.e:163-239`;
CHANGELOG "DEEPENING SWEEP 1").

What it covers: **text inside one box.** What it does not: block operations
(split, merge, move, voice assignment), which is the session-level history
`spec.md` §8.3 specifies with `is_bound_to_next` grouping and persistence in
the session file.

**Verdict:** two layers, both needed, neither replaces the other. The text
box's own undo handles keystrokes; the session command history handles
operations. `spec.md` §8.3.1's plan (build inside `simple_narrate`, promote
to `simple_undo` later) stands — and the promotion target now has a second
consumer waiting in `SW_TEXT_BOX`, which strengthens the case.

### 3.4 `simple_voice` — still a stub, size corrected

859 lines across its `.e` files (not 461), 10 `qwen` references in `src/`.
Synthesizes nothing. The seat is still the seat.

### 3.5 ⚠ `simple_speech` — no word-level timestamps

Not on the handoff's list, but it gates §S5 and `spec.md` §17.4/§17.5:

- `SPEECH_ENGINE.transcribe (samples, rate): ARRAYED_LIST [SPEECH_SEGMENT]`
  (`speech_engine.e:73`)
- `SPEECH_SEGMENT` carries `start_time`, `end_time`, `confidence`, speaker
  (`speech_segment.e:75-78`) — **segment** level
- grep `token_timestamps|max_len|split_on_word|word` over
  `engines/whisper_engine.e`: **zero hits.** whisper.cpp's word-level
  timestamp parameters are not exposed.

**Consequence:** prosody capture (§S5.2 step 2, "word-level timings") and
"prosody measured" (§17.4: silence at sentence boundaries, longest unbroken
run) need `simple_speech` extended before the S3 spike can run. whisper.cpp
supports `token_timestamps` + `max_len=1` for word granularity, so the
extension is a parameter surface, not a new engine. This is the one row where
the ecosystem needs new code before a phase can start.

---

## 4. Other stale text found while reading

| where | said | now |
|---|---|---|
| `spec-studio.md` §S9 Phase S2 | *"WebView2 shell"* | native stack — contradicted §S7.1 in the same file. **Fixed in this pass.** |
| `spec.md` §15 Phase 2 | *"`simple_vision` / EV_GRID"* | superseded by `spec-studio.md` §S7.1; left as is, since the amendment declares itself the override |
| `spec.md` §13, `HANDOFF-STUDIO.md` §5.3 | "undo/redo absent from all ~130 libraries" | see §3.3 above |
| `HANDOFF-STUDIO.md` §1, §9 | "No Eiffel has been written" | see §1 above; **handoff corrected** |

---

## 5. Still open for Larry (§5.1, unchanged)

1. Is the multi-speaker reversal (`spec-studio.md` §S2) approved in its
   recorded form?
2. Is prosody capture (§S5) worth a spike — knowing it now also needs a
   `simple_speech` word-timestamp extension first (§3.5 above)?
3. Should the Studio generate plates, or only bind them? Recommendation
   unchanged: bind only.
