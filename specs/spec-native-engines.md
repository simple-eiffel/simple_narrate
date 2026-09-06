# NATIVE ENGINES — what can be reproduced in Eiffel, and what cannot

**Larry's question:** can Piper-TTS and ComfyUI+FLUX be reproduced in pure
Eiffel with the libraries we have? Should there be a `simple_piper` and a
`simple_comfyui`? What is the feature depth?

**The answer is asymmetric, and the asymmetry is the whole point.**

| | verdict |
|---|---|
| **`simple_piper`** | ★ **Build it. Everything it needs is verified present.** A real in-process TTS engine, no server, no Python. |
| **`simple_comfyui`** | ★ **Build it — as a CLIENT.** Wrapping the protocol, not reproducing the engine. |
| **FLUX inference in Eiffel** | ❌ **Do not.** Not a language limitation — see §N4. |

---

## N1. ★ `simple_piper` — feasible, and the pieces are already on the shelf

### N1.1 What Piper actually is

Piper is not a large system. It is five steps:

```
text → normalise → espeak-ng phonemize → phoneme ids → VITS ONNX → PCM → WAV
```

There is no PyTorch, no tokenizer model, no diffusion loop. **One ONNX graph and
a lookup table.**

### N1.2 What a voice file actually contains — verified by reading one

`en_US-ryan-high.onnx.json`:

| field | value | what it means |
|---|---|---|
| `phoneme_id_map` | **130 entries**, `phoneme → [id]` | a plain lookup table |
| `num_symbols` | 130 | |
| `num_speakers` | 1 | no speaker embedding needed for these voices |
| `espeak.voice` | `en-us` | which espeak-ng voice to phonemize with |
| `inference` | `noise_scale 0.667`, `length_scale 1.0`, `noise_w 0.8` | three floats |
| `audio.sample_rate` | 22050 | |

**A 130-entry dictionary and three floats.** That is the entire configuration.

### N1.3 The graph interface

Standard VITS. Four inputs, one output:

| tensor | type / shape |
|---|---|
| `input` | int64 `[1, N]` — phoneme ids |
| `input_lengths` | int64 `[1]` |
| `scales` | float32 `[3]` = noise_scale, length_scale, noise_w |
| `sid` | int64 `[1]` — **only if `num_speakers > 1`** |
| **output** | float32 `[1, 1, samples]` — the waveform |

### N1.4 ★ `simple_onnx` already covers this — verified by reading it

| need | in `simple_onnx` | line |
|---|---|---|
| several **named** inputs in one call | `execute_multi (ARRAYED_LIST [TUPLE [name; tensor]])` | `onnx_session.e:161` |
| int64 tensors | `create_tensor_int64` | `simple_onnx.e:125` |
| float32 tensors | `create_tensor_float32` | `simple_onnx.e:101` |
| CPU / CUDA providers | `ONNX_PROVIDER` | — |

⚠ The README's headline example shows single-input `execute`, which is what made
this look harder than it is. **`execute_multi` is the feature that matters and it
is already there.** Reading past the README was the whole investigation.

### N1.5 The one C dependency: espeak-ng

Grapheme-to-phoneme is the piece Eiffel cannot reasonably reproduce — espeak-ng
encodes decades of pronunciation rules for dozens of languages.

It is a **C shared library** with a small API:

```
espeak_Initialize (AUDIO_OUTPUT_SYNCHRONOUS, 0, data_path, 0)
espeak_SetVoiceByName ("en-us")
espeak_TextToPhonemes (&text, espeakCHARS_UTF8, espeakPHONEMES_IPA)
espeak_Terminate ()
```

Four externals. That is routine for this ecosystem — `simple_onnx` itself is
ONNX Runtime's C API via inline C.

⚠ **It is still a dependency**, and honesty requires saying so: "pure Eiffel"
here means *no Python and no server*, not *no native code*. By that standard
`simple_cairo` and `simple_onnx` are not pure either.

### N1.6 Feature depth — a realistic scope

**In scope (v1):**

| | |
|---|---|
| load `.onnx` + `.onnx.json` | `simple_json` |
| espeak-ng phonemization | C externals |
| phoneme → id, with BOS/EOS and the interleaved `_` padding Piper uses | pure Eiffel |
| build the four tensors, `execute_multi` | `simple_onnx` |
| float32 → int16 PCM → WAV | pure Eiffel |
| per-call `length_scale` / `noise_scale` override | the marks in `spec-studio.md` §S6 need exactly this |
| sentence splitting + inserted silence | ★ the prototype's key pacing finding |
| multi-speaker `sid` | one extra tensor, do it now |

**Out of scope:** streaming, phoneme alignment output (Piper's models do not
export it — the prototype checked), voice training, GPU tuning.

**Estimate: 800–1,500 lines.** Most of it is marshalling. The risk sits entirely
in the espeak-ng binding and its data-path setup, not in the inference.

### N1.7 ⚠ The catch you must weigh

**The prototype rejected Piper on articulation.** Larry's verdict on the voice
that shipped was "terrible."

But the honest detail matters: the rejected voice was `norman-**medium**`, chosen
because it *measured* deepest. `ryan-**high**` articulated well and was rejected
for being too light, not for clarity — and pitch-shifting a high-quality voice
via rubberband is cheap.

> **So `simple_piper` may deliver an acceptable voice after all, and it is the
> only route to zero-server TTS.** But do not build it *expecting* Kokoro
> quality. Test `ryan-high` shifted down before committing.

★ **And it has a use even if the voice is second-best:** it is the engine that
still works when a CUDA update breaks Python on a Sunday. `spec.md` §12 wanted
exactly that property from `EDGE_TTS_ENGINE`, and this is a better version of it
because it is local.

---

## N2. ★ `simple_comfyui` — build the client, not the engine

### N2.1 The distinction that matters

**Reproducing ComfyUI** means reimplementing a node-graph execution engine, a
model loader, and a diffusion runtime. No.

**A ComfyUI client** means speaking its HTTP protocol. That is a normal library
and it is worth having on its own merits — several Simple Eiffel programs could
use local image generation.

### N2.2 Feature depth

**v1 — everything `simple_narrate` needs:**

| feature | endpoint |
|---|---|
| submit a graph | `POST /prompt` → `prompt_id` |
| poll to completion | `GET /history/<id>` |
| fetch an image | `GET /view?filename=&subfolder=&type=` |
| liveness | `GET /system_stats` |
| queue depth | `GET /queue` |
| **wait for a restarting server** | ⚠ mandatory — `spec-plates.md` §P4.1-B |
| **poll past an empty `outputs`** | ⚠ mandatory — §P4.1-A |

**v2 — worth having, not needed yet:** `POST /interrupt`, `GET /object_info`
(introspect available nodes and checkpoints), WebSocket progress events, upload
for img2img.

### N2.3 How to model a graph

The graph is a JSON map of `id → {class_type, inputs}` where an input is either a
literal or `[node_id, slot]`. Two layers:

```
COMFY_GRAPH          add_node, link, to_json
COMFY_FLUX_TXT2IMG   a typed builder: prompt, seed, steps, guidance,
                     width, height, checkpoint  →  a valid eight-node graph
```

★ **The typed builder is where the value is.** `spec-plates.md` §P2.2 records
that `cfg` must stay 1.0 for FLUX-dev while guidance lives in `FluxGuidance` —
a builder makes that structurally impossible to get wrong, where raw JSON makes
it a comment someone will ignore.

> **Preconditions worth writing:** `width \\ 16 = 0` and `height \\ 16 = 0`.
> FLUX requires it, and the prototype learned it by failing.

**Estimate: 600–1,200 lines** for v1. It is HTTP, JSON and polling.

---

## N3. Should these live inside `simple_narrate`?

**No. Both are ecosystem libraries.**

- `simple_piper` is a `TTS_ENGINE` implementation — but a Piper binding is
  useful to anything that speaks.
- `simple_comfyui` is a `PLATE_ENGINE` implementation — but local image
  generation is useful to anything that draws.

`simple_narrate` depends on both and owns neither. That is the same shape as
`simple_speech` and `simple_ffmpeg` already have here.

⚠ **And `simple_voice` is the obvious home for the Piper work** — it currently
holds the TTS seat with 461 lines that synthesize nothing. Either fill it or
retire it, but do not create a third TTS library beside a stub.

---

## N4. ❌ Why FLUX itself is not an Eiffel project

Not a language limitation. Four concrete obstacles:

1. **Scale.** FLUX-dev is a ~12-billion-parameter rectified-flow transformer,
   and it needs a **T5-XXL text encoder (~4.7B)** and CLIP-L in front of it plus
   a VAE after. That is four models, not one.
2. **The file we use is not ONNX.** `flux1-dev-fp8.safetensors` is a
   ComfyUI-flavoured safetensors checkpoint. ONNX exports of FLUX exist, are
   multi-gigabyte and multi-file, and are not what is installed.
3. **The sampler is real code.** Rectified-flow scheduling, guidance,
   timestep handling — all currently done by ComfyUI and all of it would have to
   be rewritten and then *validated against* ComfyUI to prove it matches.
4. **There is no gain.** ComfyUI already does this well, runs out of process,
   and is replaceable behind `PLATE_ENGINE`.

★ **The honest framing:** reproducing FLUX is not "writing an Eiffel program,"
it is "writing a deep-learning runtime, in order to write an Eiffel program."
Piper is different precisely because it is *one small graph and a dictionary* —
which is why the answer differs.

⚠ **And do not be tempted by a smaller model instead.** Stable Diffusion 1.5 has
tractable ONNX exports, and its output would not survive next to the FLUX plates
already produced. Reaching for it would trade the look of the series for an
architectural purity that the socket boundary already provides.

---

## N5. What this buys, and what it costs

**If both are built:**

| | before | after |
|---|---|---|
| plate generation | Eiffel HTTP client (already) | Eiffel HTTP client via a proper library |
| **TTS** | **Python server required** | ★ **in-process, no server, no Python** |
| running services | ComfyUI + TTS server | **ComfyUI only** |
| voice quality | Kokoro | ⚠ **Piper — likely a step down** |

★ **`simple_piper` removes one of the two Python services outright.** The
program becomes: Eiffel, plus `ffmpeg`, plus one image server it talks to over a
socket.

⚠ **The cost is the voice, and Larry has already heard the difference.** That is
a product decision, not an engineering one.

---

## N6. Recommendation

1. **Build `simple_comfyui` (client) now.** Low risk, immediately used, and it
   makes `spec-plates.md`'s two protocol traps structural rather than
   remembered.
2. **Build Piper into `simple_voice`** — not a new library. Do the espeak-ng
   binding first; it is the only part that can fail.
3. **Keep `TTS_ENGINE` deferred with both behind it.** Piper for the offline,
   no-server path; the HTTP engine for the best voice. That is what the boundary
   is for, and it lets the voice question stay open.
4. **Do not reproduce FLUX.**

### The decision for Larry

**Is a probably-worse voice worth removing the Python TTS service?**

If yes — build `simple_piper`, and test `ryan-high` pitched down before
committing. If the answer is "quality wins," then `simple_comfyui` is still
worth building and the TTS server stays, and that is a perfectly coherent
architecture: one Eiffel program, one binary, two sockets.
