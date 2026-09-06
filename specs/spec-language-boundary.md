# simple_narrate — WHERE THE EIFFEL STOPS

**The question Larry asked:** can this be all Eiffel, or must some of it call
Python? He would rather it were all Eiffel and suspects parts may not be
possible yet.

**The short answer: far more of it is pure Eiffel than expected — including the
plate generation, which was the part assumed hardest.** Exactly one component
has a genuine Python dependency, and `spec.md` §12 already designed the boundary
for it.

This document exists so Larry and the implementing session can make that call
together. It states what was verified, what was assumed, and what is still open.

---

## L1. The verdict table

| component | pure Eiffel? | what it needs |
|---|---|---|
| **Plate generation** | ✅ **yes, today** | HTTP + JSON. `plate.py` is 120 lines of `urllib`. |
| **Type / compositor** | ✅ **yes — and better than the Python** | `simple_cairo` + `simple_shaping` |
| **Assembly / encode** | ✅ yes | `simple_ffmpeg` + the ffmpeg binary (language-neutral) |
| **Audio capture / playback** | ✅ yes | `simple_audio` (WASAPI, verified) |
| **Session, blocks, marks, undo** | ✅ yes | `simple_toml`, `simple_hash`, `simple_diff`, `SW_TEXT_BOX` |
| **Force alignment** | ⚠ **blocked** | `simple_speech` has **no word-level timestamps** |
| **TTS synthesis** | ❌ **not today** | the one real dependency — §L4 |

**Two lines matter most: the first, because it is better news than expected, and
the last, because it is the only genuine constraint.**

---

## L2. ★ Plate generation is pure Eiffel today

This is the finding worth leading with, because "AI image generation" sounds
like the part that must be Python and it is not.

**The heavy lifting is not in our code.** FLUX inference happens inside
**ComfyUI**, which is a *server*. Our side is an HTTP client:

```
POST /prompt          send a JSON graph        → prompt_id
GET  /history/<id>    poll                     → output filenames
GET  /view?…          fetch                    → PNG bytes → disk
GET  /system_stats    liveness probe
```

That is it. `plate.py` imports `json`, `urllib`, `shutil`, `time` — nothing
numerical, no model, no tensor. **Python contributes nothing here that Eiffel
lacks.** `simple_json` builds the graph, `simple_http`/`simple_winhttp` carries
it, `simple_file` writes the PNG.

Calling ComfyUI from Eiffel is the same act as calling a database. Nobody
describes a program as "partly SQL" because it opens a connection.

> **Recommendation: implement `COMFY_PLATE_ENGINE` in Eiffel from the start.**
> There is no spike needed and no Python to retire later.

⚠ The two protocol traps in `spec-plates.md` §P4.1 — the history entry that
appears before its outputs, and the dead server that must be waited out rather
than failed — are *client* bugs. They will reappear in Eiffel unless the Eiffel
handles them. That is what the reference implementation is for (§L6).

---

## L3. ★ The compositor should be Eiffel, and it will be *better*

The Python renders the type layer as **HTML/CSS → headless Edge → PNG → crop**.
That was the right call in Python — a browser was the fastest way to get shaped
text and CSS layout.

**In Eiffel it is the wrong call, and the native path is strictly better:**

| | HTML + headless Edge | `simple_cairo` + `simple_shaping` |
|---|---|---|
| Hebrew / Greek | yes | yes — bidi, itemization, fallback |
| external dependency | **Microsoft Edge** | none |
| the 30×96 chrome-offset trap | **exists** (`spec-plates.md` §P5.1-A) | **cannot exist** |
| the image-decode race | **exists** (§P5.1-B) | **cannot exist** |
| same renderer as the Studio preview | ❌ no — two renderers, drift possible | ✅ **yes, one renderer** |
| process launch per frame | yes | no |

★ **The last row is the real argument.** In the Python pipeline the Studio
preview and the exported frame would be two different renderers, and any
disagreement between them is a bug you cannot see until export. In Eiffel, the
block list the user edits and the frame that ships are drawn by the same Cairo
code. **What you see is what renders**, by construction rather than by care.

And two documented bugs simply cease to exist rather than being ported.

> **Recommendation: no browser anywhere in the Eiffel implementation.** This is
> consistent with `simple_chat`'s stated position — *"no browser, no WebView,
> no HTML anywhere."*

---

## L4. ❌ TTS — the one genuine dependency

### L4.1 Why it cannot be Eiffel today

A modern TTS voice is not a function; it is a neural pipeline:

```
text → normalisation → grapheme-to-phoneme → phoneme ids
     → acoustic model → vocoder → PCM
```

| candidate | why not in-process Eiffel |
|---|---|
| **Chatterbox** (`spec.md` §15's first choice) | a **PyTorch pipeline**, not a single graph. Not exportable to one ONNX file. |
| **Kokoro-82M** (the prototype's voice) | ONNX export exists, but needs **espeak-ng phonemization in front of it**, and its G2P layer (`misaki`) is Python |
| **Piper** | ★ genuinely "one ONNX file + phonemes" — **but the prototype rejected it on articulation**, which is why Kokoro was chosen |

The other session verified `simple_onnx` independently and reached the same
place (`verification-2026-09-05.md` §3.1): *the binding is sound; the obstacle is
the models.*

**The cruel detail:** the one candidate that *would* run in-process is the one
that was rejected for sounding worse. That is not a tooling problem.

### L4.2 The three options

**A. HTTP to a local Python TTS server** — `spec.md` §12's `LOCAL_TTS_ENGINE`,
"exactly as `ocr_engine` → `ocr_http` → Ollama. **Eiffel never sees Python.**"

- ✅ Works today, any model, no Eiffel/Python interop
- ✅ Same architecture as plate generation — one pattern for both
- ⚠ A Python service must be installed and running

**B. `ONNX_TTS_ENGINE` in-process** — `simple_onnx` + espeak-ng via C externals

- ✅ Zero Python, zero server, single-process
- ❌ Piper-only in practice, and Piper is the voice you rejected
- ⚠ espeak-ng is a C DLL — routine for Eiffel, but it *is* a C dependency

**C. `recorded` slots only** — no synthesis at all (`spec-studio.md` §S3.2)

- ✅ Zero dependency of any kind. Genuinely all-Eiffel.
- ❌ You read everything, forever, including after every edit

### L4.3 Recommendation

**Option A now, keep B as a later engine behind the same boundary.**

This is what `TTS_ENGINE` being deferred *is for*. The boundary already exists;
choosing A costs nothing later, because B slots in behind the same interface
without touching a block, a session file, or the GUI.

★ **And note what A actually means for the "all Eiffel" goal.** ComfyUI is a
Python server we call over HTTP and nobody minds. A TTS server is the identical
arrangement. **The program is Eiffel; two of its appliances happen to be written
in Python, and it never links, embeds, or imports them.**

⚠ **Do not embed Python.** No CPython in-process, no `simple_python` bridge for
this. The moment Eiffel imports Python you inherit its GIL, its exceptions, its
environment and its upgrade schedule. A socket is a much better fence than an
FFI, and `spec.md` §12 already chose it.

---

## L5. ⚠ Force alignment is blocked, and it blocks prosody capture

`verification-2026-09-05.md` §3.5: **`simple_speech` has no word-level
timestamps.**

That is a direct hit on `spec-studio.md` §S5. Prosody capture works by comparing
*your* word timings against a synthesized baseline; without word timings there
is nothing to compare.

Three ways forward:

1. **Extend `simple_speech`** to emit word timestamps. The underlying engines
   generally expose them; this may be surfacing rather than building.
2. **Force-align through the same HTTP pattern** as TTS — whisperX is already
   installed on this machine and does exactly this.
3. **Cut §S5.** It was always the cuttable phase with an explicit kill gate.

> **This should be resolved before Phase S3 is scheduled, not during it.** It
> does not block Phases 1 or S2 at all.

---

## L6. What to do with the Python

**Point at it. Read it. Do not port it, and do not call it.**

```
D:\_videos\_Claude-Explainers\_tools\
  plate.py        120 lines — the ComfyUI protocol and every FLUX parameter
  build.py        the assembly: sentence-split TTS, caption timing, zoom, captions
  verify.py       what "verified" means for a deliverable
  preflight.py    what to check before spending GPU hours
  README.md       the field report, with the "things that cost time" section
```

**Its value is the decisions, not the code.** Most lines are ordinary; the
comments record *why each number is what it is* — why guidance is 2.6 and not
3.2, why `cfg` stays at 1.0, why the style string is a prefix, why the window is
oversized by 30×96, why zoom is rate-governed. Those were all bought with
failures, and they transfer to Eiffel unchanged.

⚠ **Two files are anti-patterns to read and not imitate.** `build.py`'s
compositor is HTML-and-browser (§L3 replaces it), and its early plate fallback
is the bug that built an episode on the wrong artwork (`spec-plates.md` §P7).

**It is not a dependency.** When the Eiffel works, the Python is a historical
record. Nothing should ever shell out to it.

---

## L7. So how "all Eiffel" is it?

Honestly scored, by where the work is:

| | |
|---|---|
| **Eiffel** | session model, blocks, marks, undo, GUI, plate client, prompt assembly, compositor, timing, captions, assembly orchestration, verification, export |
| **External binary** | `ffmpeg` — as every media program on earth does |
| **External service** | ComfyUI (images), TTS server (voice) — HTTP, out of process, replaceable |
| **Python inside our program** | **none** |

**No Eiffel source file imports, links, or embeds Python.** Two appliances are
reachable over a socket and both sit behind a deferred class, which is the same
relationship a program has with a database.

If the goal is *"no Python on the machine at all,"* that costs Option B and the
Piper voice, and it is a real trade you may not want. If the goal is *"my program
is Eiffel,"* **you already have that** — including, pleasingly, the plate
generation.

---

## L8. The decision for Larry and the implementing session

1. **Confirm the TTS boundary** — Option A (HTTP, `spec.md` §12) versus B versus
   C. My recommendation is A, with B kept as a later engine.
2. **Confirm no browser in the compositor** (§L3). This is a change from the
   Python and it removes two documented bug classes.
3. **Decide the force-alignment route** (§L5) before Phase S3 is scheduled —
   extend `simple_speech`, HTTP to whisperX, or cut §S5.
4. **Confirm `plate.py` is a reference and never a dependency** (§L6).
