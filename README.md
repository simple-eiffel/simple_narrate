# simple_narrate

**[Specification](specs/spec.md)** | **[GitHub](https://github.com/simple-eiffel/simple_narrate)**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Eiffel](https://img.shields.io/badge/Eiffel-25.02-blue.svg)](https://www.eiffel.org/)
[![Design by Contract](https://img.shields.io/badge/DbC-enforced-orange.svg)]()
[![Status](https://img.shields.io/badge/status-Phase_S2_step_1-blue.svg)]()

Turn an essay you wrote into a narrated recording you would actually publish —
running entirely on your own machine, and refusing to call the job done on
evidence it does not have.

Part of the [Simple Eiffel](https://github.com/simple-eiffel) ecosystem.

---

## Status: the Studio shell stands (Phase S2, step 1)

**2026-09-06.** The Studio window exists and is proven headless: `narrate.exe`
opens one `SW_WINDOW` with shaped text on, the seven-pad menu bar (File / Edit /
Block / Voice / Render / Export / Help), a toolbar, the breadcrumb strip, an
`SW_DOCK_HOST` whose three zones stand empty around an empty-state centre, and
the status bar. Step 1's gate from [`specs/spec-studio-frame.md`](specs/spec-studio-frame.md)
§F7 - *the window opens, and Hebrew in a label reads right-to-left* - is asserted
on the breadcrumb's own shaped layout and written to `evidence/studio-shell-hebrew.png`.
Nothing behind the frame knows a block yet; steps 2-10 seat the thread, the
inspector, the palette and the transport into it.

```bash
/d/prod/ec.sh test -config simple_narrate.ecf -target simple_narrate_tests
./EIFGENs/simple_narrate_tests/F_code/simple_narrate.exe     # 5 passed, 0 failed
/d/prod/ec.sh test -config simple_narrate.ecf -target narrate
./EIFGENs/narrate/F_code/simple_narrate.exe                  # the Studio, on a desktop
```

`cairo.dll` (from `simple_cairo/`) goes beside either executable.

Targets: `narrate` (the Studio), `simple_narrate_tests`, and `narrate_editor` -
the August 2026 pure-Win32 block editor in `narrate_gui/`, kept buildable as the
reference whose text engine became `simple_widgets`' `SW_TEXT_BOX`.

The design is in [`HANDOFF-STUDIO.md`](HANDOFF-STUDIO.md) (read it first) and the
specs it orders: [`specs/spec.md`](specs/spec.md) is the base, `spec-studio.md`
the amendment, `spec-studio-frame.md` the window drawn to the widget,
`spec-marks-as-spans.md` the speaking-function palette. The three Phase 0
questions still gate the *engine* side, and a Python spike in [`spike/`](spike/)
still answers them, not more specification:

1. Does a local model hold one voice across 28 minutes, or drift?
2. Does a spliced emphasis sound like a person leaning on a word, or like a splice?
3. What does one block re-render actually cost in wall-clock time?

---

## The idea

★ **Two gates. Neither one is sufficient.**

- **The number** — synthesise a paragraph, transcribe it back, diff against the
  source. This proves *the words survived*.
- **The ear** — you listened to this paragraph and blessed it. This proves *the
  reading is right*.

A round-trip measures intelligibility, not correctness: it cannot tell you whether
*read* was spoken as *reed* where the sentence needed *red*. An ear twenty minutes
into a twenty-eight minute recording will not catch a mangled proper noun.
**Publishing requires both, and the tool tracks both as state.**

Everything else in the specification is machinery for making both cheap enough to
satisfy — chiefly a content-addressed render cache, so that reordering paragraphs
costs nothing, changing one word re-renders one paragraph, and undo is free.

---

## Design highlights

| | |
|---|---|
| **Application, not a library** | Same standing as [`simple_ocr_capture`](https://github.com/simple-eiffel/simple_ocr_capture) |
| **Local and free** | No paid service anywhere in the design |
| **Named after the job** | The model is a settings value, never part of the name |
| **One session file** | Readable TOML, autosaved atomically, undo history doubling as the recovery journal |
| **Proven, not guessed** | Pronunciation entries are promoted only after a round-trip returns the intended word |

---

## Ecosystem dependencies

Verified by reading them, not assumed:

| library | role |
|---|---|
| [`simple_speech`](https://github.com/simple-eiffel/simple_speech) | the round-trip gate |
| [`simple_hash`](https://github.com/simple-eiffel/simple_hash) | `sha256` for content addressing |
| [`simple_toml`](https://github.com/simple-eiffel/simple_toml) | the session file |
| [`simple_diff`](https://github.com/simple-eiffel/simple_diff) | fidelity diff and source re-import |
| [`simple_ffmpeg`](https://github.com/simple-eiffel/simple_ffmpeg) | assembly and encoding |
| [`simple_markdown`](https://github.com/simple-eiffel/simple_markdown) | essay import |
| [`simple_uuid`](https://github.com/simple-eiffel/simple_uuid) | block identity |
| [`simple_audio`](https://github.com/simple-eiffel/simple_audio) | per-block playback |
| [`simple_voice`](https://github.com/simple-eiffel/simple_voice) | to become the `TTS_ENGINE` boundary |

---

## Licence

MIT — see [LICENSE](LICENSE).
