# simple_narrate

**[Specification](specs/spec.md)** | **[GitHub](https://github.com/simple-eiffel/simple_narrate)**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Eiffel](https://img.shields.io/badge/Eiffel-25.02-blue.svg)](https://www.eiffel.org/)
[![Design by Contract](https://img.shields.io/badge/DbC-enforced-orange.svg)]()
[![Status](https://img.shields.io/badge/status-specification-lightgrey.svg)]()

Turn an essay you wrote into a narrated recording you would actually publish —
running entirely on your own machine, and refusing to call the job done on
evidence it does not have.

Part of the [Simple Eiffel](https://github.com/simple-eiffel) ecosystem.

---

## ⚠ Status: specification only

**There is no code in this repository yet.** No Eiffel has been written, nothing
has been compiled, and none of the contracts in the specification have seen
`ec.sh check`. The specification says so in its own margins.

What is here is [`specs/spec.md`](specs/spec.md) — 20 sections covering the design,
the ecosystem dependencies that were verified by reading them, a full Design by
Contract layer, and a testing plan targeting assertion coverage.

The next step is a Python spike in [`spike/`](spike/), not more specification.
Three questions gate everything else, and no amount of design settles them:

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
