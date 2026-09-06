# HANDOFF — simple_narrate / The Studio

**You are picking up a design, not a codebase.** ⚠ *Corrected 2026-09-05:* an
1,584-line `NARRATE_GUI` block editor DOES exist in `narrate_gui/` (caret,
selection, split-tint, block model); its text engine was harvested into
`simple_widgets` as `SW_TEXT_BOX`. See `specs/verification-2026-09-05.md` §1.

Read this file first; it tells you what exists, what is decided, what is
open, and what has already been proven by a working prototype in another
language.

Written 2026-09-05 at the end of the session that produced the design.

---

## 1. What is being built, in one paragraph

A local, offline replacement for ElevenLabs Studio: a **block-based narration
workbench**. You import an essay, it splits into blocks, each block renders to
audio through a local TTS engine, you edit text and marks per block and
re-render just that block, you assign a voice per block from a palette, you bind
artwork to spans of blocks, and you export a narrated recording plus the timing
data a video assembler needs. Nothing leaves the machine.

---

## 2. Read in this order

| # | file | what it is |
|---|---|---|
| 1 | **this file** | context, decisions, open questions |
| 2 | `specs/spec.md` | **the base spec.** 1,410 lines, 20 sections. Pre-existing, thorough, and still authoritative except where the amendment says otherwise. |
| 3 | `specs/spec-studio.md` | **the amendment.** 497 lines. Voice palette, plates, prosody capture, the mark notation, the GUI decision. |
| 4 | `specs/spec-plates.md` | **how the artwork is made.** The ComfyUI/FLUX graph, the prompt construction, the composition rule, the two headless-browser quirks, and the verification rules. Derived from ~200 plates actually generated. |
| 5 | `specs/spec-language-boundary.md` | **where the Eiffel stops.** Component-by-component: what is pure Eiffel (more than expected — including plate generation), what needs an external service, and the one genuine Python dependency. Ends with four decisions for Larry. |
| 6 | `specs/spec-native-engines.md` | **can we replace the appliances?** `simple_piper` — feasible, everything verified present. `simple_comfyui` — build the client, not the engine. FLUX in Eiffel — no, with reasons. |
| 7 | `D:\prod\simple_comfyui\specs\spec.md` | **new library — build plan.** The Eiffel ComfyUI client, the typed FLUX graph builder, and the layer question answered (§C0). |
| 8 | `specs/spec-studio-frame.md` | **the Studio window, drawn to the widget.** ElevenLabs Studio (screenshot + docs) inventoried; keep / adapt / drop per feature; every region mapped to a real `simple_widgets` class; toolkit gaps; Phase S2 build order. |
| 8b | `specs/spec-marks-as-spans.md` | **marks as spans, not notation** (2026-09-06). Speaking functions are applied to a selection from a palette and remembered as spans that follow edits; the toolkit side is built (`simple_widgets` 0.8.0 highlights). Amends spec-studio S6. |
| 9 | `D:\prod\simple_voice\specs\spec-piper.md` | **fill the stub — build plan.** Piper in-process via `simple_onnx` + espeak-ng. Larry: *"fill it, don't retire it."* |
| 10 | `README.md` | short; largely superseded by the verification note |

`spec.md` §16 is titled *"Measured against ElevenLabs"* and §17 goes through
request stitching, character alignment, pronunciation dictionaries and Studio's
lock-and-history. That work is done. Do not redo it.

---

## 3. Where this came from — the backdrop that is not in the specs

This design did not arrive from nowhere. It came out of building a **working
video-explainer pipeline in Python**, which is running and has shipped twelve
finished episodes. That pipeline is the closest thing to a Phase 0 spike that
exists, and it settles several questions empirically.

```
D:\_videos\_Claude-Explainers\
  README.md      the pipeline, and a "things that cost time to learn" section
  HANDOFF.md     its own status and content rules
  _tools\        build.py, plate.py, preflight.py, verify.py, script_md.py, ...
  PRISM\ ZAKAR\ EBF\    three series; two fully rendered
```

**Read `D:\_videos\_Claude-Explainers\README.md`.** It is the field report.

### What the prototype already proves

| question | answer, from running code |
|---|---|
| Does local TTS work offline at quality? | **Yes.** Kokoro-82M, GPU, ~9 min of audio per episode. |
| Sentence-split + inserted silence for pacing? | **Yes** — and it is what made narration stop sounding rushed. `length_scale` alone did not. |
| Can caption timing come from measured spans? | **Yes.** Synthesizing per sentence yields exact boundaries; error cannot accumulate past one sentence. |
| Does punctuation control prosody? | **Barely.** Measured: commas move duration 0.5%. Table in `spec-studio.md` §S6.2. |
| Do the engines read SSML? | **No.** Piper and Kokoro are plain-text. Stray markup is *mangled*, not ignored — `*asterisks*` added a full second. |
| Block-level re-render loop? | **Not tried.** This is still Phase 0's open question. |

### Hard-won failure modes — these transfer directly

The prototype shipped three bugs worth inheriting the lessons from:

1. ⚠⚠ **A silent fallback built a whole episode on the wrong artwork.** When the
   image server died mid-run, a "use a placeholder if missing" convenience path
   substituted another episode's plates and **reported success**. Removed; a
   missing asset is now a hard error. *Design consequence:* `spec-studio.md`
   §S7.3 makes block state impossible to miss, and §S3.5 adds a voice-assignment
   invariant for exactly this class.

2. ⚠⚠ **A truncated MP4 sat in the output folder looking finished** — plausible
   size, no moov atom, would not open. `ls` cannot tell you a video is broken.
   Hence `verify.py`, which *opens* every deliverable and decodes the tail.
   *Design consequence:* **existence is not currency.** `spec.md`'s gate is the
   right instinct; keep it.

3. ⚠ **A dead server was treated as permanent failure**, burning through a queue
   in seconds against a closed port. Now it waits the server out.

---

## 4. Decided — do not relitigate without asking

| decision | authority |
|---|---|
| **GUI is the native stack:** `simple_widgets` + `simple_cairo` + `simple_shaping`. **No WebView, no HTML.** | Larry, explicitly, 2026-09-05 |
| **`simple_chat` is the reference implementation to copy** for shaped text | Larry, explicitly |
| The ElevenLabs layout is **a starting target that will change** | Larry, explicitly |
| Multi-voice: **one voice per block**, from a palette | Larry (see §5.1 — it overturns a stated non-goal) |
| Model choice stays a settings value behind `TTS_ENGINE` | `spec.md` §4, §12 |
| First TTS candidate: **Chatterbox** (MIT, ~6 GB, per-segment `exaggeration`) | `spec.md` §15 |
| **Wrapping C is fine.** "Pure Eiffel" means no Python and no embedded runtime — not no native code. | Larry, 2026-09-05 |
| **`simple_voice` gets filled with Piper, not retired** — it has a consumer | Larry, 2026-09-05 |
| **`simple_comfyui` is a new library** — a client, never a ComfyUI reimplementation | Larry, 2026-09-05 |
| **FLUX inference is NOT reproduced in Eiffel** | `spec-native-engines.md` §N4, `simple_comfyui` §C0 |

★ **On the GUI decision — a correction worth knowing about.** An earlier draft
chose WebView2, justified by "simple_widgets cannot render Hebrew." **That was
stale and false.** `simple_shaping` exists for exactly this — bidi, itemization,
glyph fallback — and `simple_chat` ships it: *"no browser, no WebView, no HTML
anywhere… Hebrew reads right-to-left inside a left-to-right pane, Greek keeps
its accents."* Copy `SW_SHAPING` and `SW_CHAT_VIEW`.

---

## 5. Open — needs Larry, or needs a spike

### 5.1 ✅ DECIDED by Larry 2026-09-05

1. Multi-speaker reversal: **approved** as recorded in §S2.
2. Prosody capture: **spike it.** `simple_speech` word timestamps land first.
3. Plates: ⚠ **"bind only" was REVERSED by Larry later the same day** —
   *"this will be a full-service process on simple_narrate."* Generation is in
   scope. See `specs/spec-plates.md` §P0, which records the reversal and keeps
   the part of the original decision that was protecting something real: an
   empty plate slot is **shown, never substituted**, and generation is a service
   the Studio *calls*, never something it does automatically.

Original questions kept below for the record.


1. **Is the multi-speaker reversal approved?** `spec.md` §4 declares *"Not
   multi-speaker. One narrator, one essay."* The amendment overturns it. It is
   recorded as a reversal with its costs (`spec-studio.md` §S2), not quietly
   absorbed. **He requested it, but has not confirmed the recorded form.**
2. **Is prosody capture (§S5) worth a spike?** Most interesting idea here, most
   likely to fail. It has an explicit kill gate.
3. **Should the Studio generate plates, or only bind them?** §S4.3 holds the
   boundary. Recommendation: hold it.

### 5.2 ✅ ANSWERED 2026-09-05 — and BUILT: `simple_widgets` 0.8.0 (see `specs/spec-studio-frame.md` §F6)

Short form: the cluster map is published per run (`GLYPH_RUN.cluster_map`,
`x_positions`), the RTL-aware boundary walk exists in `SW_CHAT_THREAD`
(read-only selection), and `SW_TEXT_BOX` is unshaped. Editing a shaped run is
wiring work, not invention. Build S2 on the §S7.1 fallback; queue a shaped
`SW_TEXT_BOX` in `simple_widgets`. Original question kept below for the record.


**Does the shaping layer expose cluster-to-byte mapping?** Displaying shaped
text is proven by `simple_chat`. Placing a **caret inside** a Hebrew run,
selecting across a bidi boundary, and hit-testing a click to a byte offset are
not obviously proven. `spec.md` §8.4 (cursor-not-selection splitting) depends on
it. **Read `CHAT_INPUT_BOX` first.** A fallback exists (`spec-studio.md` §S7.1)
if the answer is no.

### 5.3 ✅ CLOSED 2026-09-05 — see `specs/verification-2026-09-05.md` §3

Short form: `simple_onnx` is sound but the candidate models are not single
graphs, keep the HTTP hop; `simple_ffmpeg` has no loudness feature but
`transcode_with_args` passes `-af loudnorm` through today; undo/redo EXISTS
at text level in `SW_TEXT_BOX`, session-level history still per `spec.md`
§8.3. ⚠ New row: `simple_speech` exposes no word-level timestamps, which §S5
prosody capture needs. Original list kept below for the record.


`spec.md` §13's discipline is **verified means someone read it**, and its own
lesson is that draft 1 hand-rolled four things the ecosystem already had. These
have *not* been read:

- `simple_onnx` — could allow in-process TTS, skipping the HTTP hop
- `simple_ffmpeg` — **loudness normalisation presumed absent**; concat and
  silence are already known absent (`spec.md` §14.1)
- Whether anything covers **undo/redo** — §13 says absent from all ~130 libraries

Known and unchanged: **`simple_voice` is a 461-line stub that synthesizes
nothing.** It keeps the engine seat; the Qwen stubs come out.

---

## 6. Phasing

From `spec.md` §15, extended by `spec-studio.md` §S9:

- **Phase 0** — Python spike. Chatterbox. Four kill questions (three from
  `spec.md`, plus: does prosody capture produce usable marks?). *Much of this is
  already answered by the video prototype — see §3 above.*
- **Phase 1** — CLI. Session file, blocks, render, assemble, gate. **Add now:**
  `voice_id` on the block, `recorded` slots, plate bindings — data-model work
  that avoids a migration later.
- **Phase S2** — the Studio. Native stack. Block list, palette, playback,
  regeneration, takes, state display.
- **Phase S3** — prosody capture. **Cuttable** without affecting anything else.
- **Phase S4** — export an edit decision list the video assembler consumes.

---

## 7. What this is not

Restated because a program that gains a GUI attracts feature requests:

- Not a DAW — no EQ, compression, music beds, ducking, timeline
- Not overlapping speakers — one voice per block
- Not an image generator — plates arrive as files
- Not a TTS or STT library — both stay behind boundaries
- **Not a cloud service.** Nothing leaves the machine.

---

## 8. House rules that apply to this work

From the ecosystem's standing practice — worth stating since you are new to this
session's context:

- **`ec.sh` modes only** — `test` / `check` / `run` / `release`. It refuses
  `-c_compile`. A clean-looking log with no exe is the banner.
- **Any waiting C external must be `C blocking`**, or a garbage collection waits
  on it and every processor freezes.
- **Unique C prefix per library** (`simple_console` → `scon_`, not `sc_`) —
  a prefix collision has already cost a day once.
- **Check downstream dependents after changing a library:** map ECF dependents,
  clean-build and test each, before calling the change done.
- **Push means README and `/docs` updated too.**
- **Never verify installers under the live AppId** — verify builds get a
  `-verify` identity.
- **Larry gates scope changes.** The multi-speaker reversal in §5.1 is the live
  example.

---

## 9. Fastest path to being useful

1. Read `specs/spec.md` §§1–15, then `specs/spec-studio.md` end to end.
2. Read `D:\_videos\_Claude-Explainers\README.md` for what the prototype proved.
3. ~~Read `simple_chat`'s `SW_CHAT_VIEW` and `CHAT_INPUT_BOX` — answer §5.2.~~ **Done.**
4. ~~Close the three unverified ecosystem rows in §5.3 by **reading** them.~~ **Done.**
5. Take §5.1 to Larry as three questions, not as assumptions. **Asked 2026-09-05; awaiting answers.**
6. Then Phase 0's spike — and note how much of it §3 already answers.

**Do not start with Eiffel.** `spec.md` §15 is explicit that the next step is a
Python spike, not more specification and not code.
