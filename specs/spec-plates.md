# simple_narrate — PLATE GENERATION

**How the artwork is actually made.** A specification derived from a running
Python implementation that has produced ~200 plates across three series and
twelve shipped episodes. Every number here was measured, not chosen.

Companion to [`spec.md`](spec.md) and [`spec-studio.md`](spec-studio.md).

Reference implementation: `D:\_videos\_Claude-Explainers\_tools\plate.py`
and `build.py`. Read them; they are short and they work.

---

## P0. ⚠ A scope reversal, recorded

`spec-studio.md` §S4.3 says the Studio **binds** plates and does not generate
them: *"Not an image generator. Plates arrive as files."* Larry recorded that as
decided on 2026-09-05 — *"bind only… the picture arrives later."*

**That is now reversed.** Larry, same day: *"this will be a full-service process
on simple_narrate."* Generation comes in scope.

**What the earlier decision was protecting, and how to keep it.** The reason for
"bind only" was sound: *the image is downstream of text that may still change.*
Generating early means regenerating often, and a plate is ~110 s of GPU. So:

> **The boundary that survives the reversal.** Generation is a **service the
> Studio calls**, behind an interface, exactly as `TTS_ENGINE` is. It is never
> automatic. A block span with no plate shows as empty and is **never
> substituted** — that rule (§S4.3, and P7 below) is the one that must not bend,
> because breaking it is precisely how the Python pipeline shipped an episode
> built on another episode's artwork.

```
PLATE_ENGINE (deferred)
    generate (a_prompt: STRING_32; a_seed: INTEGER; a_out: PATH): BOOLEAN
    is_available: BOOLEAN
    last_error: STRING_32
    last_duration_ms: INTEGER
```

Effective backend: `COMFY_PLATE_ENGINE`, HTTP+JSON to a local ComfyUI. Same
shape as `LOCAL_TTS_ENGINE` in `spec.md` §12 — *Eiffel never sees Python.*

---

## P1. The central rule: two layers, never one

**Paint underneath. Type composited on top. Always.**

The plate carries ground colour, texture and painted subjects. **It never
carries a glyph.** All text — titles, panels, captions, episode numbers — is
composited afterwards from HTML/CSS.

Two reasons, and the second is the one people miss:

1. **Diffusion models garble text.** Every model, still, at this size.
2. **The reference aesthetic was already composited.** The style being imitated
   has clean typography *because a designer set it*, not because a model drew
   it. Trying to generate the type is imitating the wrong half of the picture.

Consequence: type stays vector-crisp at any scale, is editable without
regenerating a 110-second image, and can be animated later.

---

## P2. The generator

### P2.1 Backend

| item | value | why |
|---|---|---|
| server | ComfyUI, `127.0.0.1:8188` | local, no key, already installed |
| launch | `--disable-auto-launch --fast fp16_accumulation` | ⚠ **`--disable-auto-launch` matters** — nothing opens on the user's desktop |
| checkpoint | `flux1-dev-fp8.safetensors` | all-in-one; loads via `CheckpointLoaderSimple`, no separate CLIP/VAE |
| resolution | **1536 × 864** | exactly 16:9, **and both axes divide by 16**, which FLUX requires |

⚠ **The /16 constraint is not optional.** 1920×1080 fails (1080/16 = 67.5).
1536×864 is the largest clean 16:9 that renders in ~110 s on a 5070 Ti.

### P2.2 The graph

Eight nodes. Minimal on purpose.

```
1  CheckpointLoaderSimple   ckpt_name = flux1-dev-fp8.safetensors
2  CLIPTextEncode           positive  ← clip [1,1]
3  CLIPTextEncode           negative  = ""          (empty, deliberately)
4  FluxGuidance             guidance  = 2.6         ← conditioning [2,0]
5  EmptyLatentImage         1536 × 864, batch 1
6  KSampler                 seed, steps 18, cfg 1.0,
                            sampler euler, scheduler beta, denoise 1.0
7  VAEDecode                samples [6,0], vae [1,2]
8  SaveImage                filename_prefix = "plate"
```

⚠ **`cfg` is 1.0 and stays 1.0.** FLUX-dev takes its guidance from the
`FluxGuidance` node, not from KSampler's cfg. Raising cfg here degrades output.

⚠ **The negative prompt is empty on purpose.** FLUX-dev at cfg 1.0 does not use
it. Filling it in does nothing and misleads whoever reads the graph next.

**Tuning history, so it is not rediscovered:** guidance began at 3.2 and steps at
22 — that produced *photographs*. 2.6 / 18 is painterly and ~45 % faster.

### P2.3 Timing, measured

| condition | per plate |
|---|---|
| FLUX resident, GPU free | **~110 s** |
| memory pressure, model reloading | **~215 s** |
| first plate after server start | ~240 s |

Budget **~14 plates/episode ≈ 25–50 min GPU**. This is the pipeline's long pole,
not encoding and not TTS.

---

## P3. The prompt — where most of the quality lives

### P3.1 Three parts, in this order

```
<STYLE_PRE>  <subject>.  <STYLE_POST>
```

⚠⚠ **Style goes in the PREFIX. This is the single most important finding in this
document.** FLUX weights early tokens far more heavily. A trailing style string
gets read as *"a photograph of a textured wall"* rather than *"everything here is
made of paint."* The first plate ever generated came out photorealistic for
exactly this reason.

**STYLE_PRE** (verbatim, from the working implementation):

> A thick impasto oil painting. Every object in this picture is built from heavy
> palette-knife strokes of oil paint, ridged and troweled, paint standing up off
> the canvas in visible sculpted ribbons. Expressive painterly portraiture, bold
> loaded brushwork, chunky slabs of colour. Subject:

**STYLE_POST**:

> painted entirely in thick textured impasto oil paint, palette knife technique,
> no text, no letters, no numbers, no writing, no signature, no frame

### P3.2 Words that must never appear

⚠ **"photography", "photograph", "flat even lighting", "museum photography".**
All were in the first draft. All pull hard toward realism and away from paint.

### P3.3 Describe subjects as *made of* paint

Not *"a portrait of a philosopher"* but *"a painted portrait head built from
thick slabs of grey and cream paint."* The style prefix sets the medium; the
subject description must not quietly re-assert photorealism.

### P3.4 ★ The composition rule — subjects at the edges

**Every subject sits at the far left edge, the far right edge, or along the
bottom edge. The centre of the frame is left as empty flat ground.**

This is not aesthetics. **The composited card lands in the centre.** A plate with
its subject centred produces a frame where the artwork is hidden behind text and
the whole two-layer scheme is wasted.

The subject template that works:

> `<ground>. At the far left edge, <thing>. At the far right edge, <thing>.`

with `<ground>` = *"a deep teal-green painted ground filling the whole frame,
the centre of the frame left as empty flat teal paint."*

### P3.5 Series identity is the ground colour

One ground colour per series, stated in every prompt of that series and matched
by the CSS `--ground`. It is what makes a channel grid legible.

| series | colour | prompt phrase |
|---|---|---|
| PRISM | `#17706B` | "deep teal-green painted ground" |
| ZAKAR | `#22375C` | "deep midnight indigo-blue painted ground" |
| EBF | `#73461F` | "deep burnt amber painted ground" |

★ Choose warm against cool. Two cool series (teal, indigo) read as related; the
third wants warmth or the set flattens.

### P3.6 Subjects should carry the argument

The plate is not decoration. The strongest results came from objects that *are*
the point: an empty throne and a fallen crown for "who is on the throne inside
you"; a row of clay jars tipped over and emptied for a list of words whose
contents were carried out; a lit doorway with an empty chair for "the Auditor
still in residence."

Write the subject from the block's **single idea**, not from its nouns.

---

## P4. The protocol

```
POST /prompt          {"prompt": <graph>}        → {"prompt_id": ...}
GET  /history/<id>    poll                       → outputs.<node>.images[]
GET  /view?filename=&subfolder=&type=output      → the PNG bytes
GET  /system_stats                               → liveness probe
GET  /queue                                      → running / pending counts
```

### P4.1 ⚠ Two failure modes that cost real work

**A. The history entry appears before its outputs are populated.** Treating
"entry exists, `outputs` empty" as fatal aborts jobs that are running fine — it
reported two false failures on a real run whose images landed seconds later.

> **Keep polling until timeout. Only an explicit `status_str == "error"` is
> fatal.**

**B. A dead or restarting server must be waited out, not failed.** ComfyUI was
killed mid-run; the generator burned through ten queued plates in seconds
against a closed port, and the build then proceeded on missing artwork.

> **Probe `/system_stats` before submitting. Block up to ~10 minutes.** The
> server was back in three.

### P4.2 Determinism

`seed` is explicit per plate and recorded. Same seed + same prompt + same
checkpoint reproduces the image. **Store both with the plate** — `spec-studio.md`
§S4.2 already has the nullable `prompt`/`seed` fields for this.

---

## P5. The type layer

Rendered as HTML/CSS, screenshotted headless, composited over the plate.

### P5.1 ⚠ Headless-browser quirks — both silent

**A. `--window-size` is the WINDOW, not the viewport.** Edge takes 30 × 96 for
chrome, so asking for 1920×1080 lays the page out at **1890×984** while still
writing a 1920×1080 PNG. Content renders 1:1 and the overflow is left as bare
canvas colour — a band of ground down the right edge and along the bottom.

> **Oversize the window by the chrome, then crop back to 1920×1080.**

**B. `--virtual-time-budget` is mandatory.** Without it the screenshot fires
before a multi-megabyte plate has decoded, silently returning a frame with flat
ground where the painting should be. Use ≥ 4000 ms.

### P5.2 Composition rules that took iteration

- **Cards are translucent** — `rgba(…, .72)` with `backdrop-filter: blur(20px)`.
  Opaque cards waste the artwork; that was the first note back from review.
- **Cards shrink to content**, not fixed width.
  ⚠ An absolutely-positioned shrink-to-fit box at `left:50%` only gets the
  **right half** of the frame as available width, so its content wraps at 960 px
  regardless of `max-width`. Use a flex stage.
- **The running head sits top-left**, because the lower third belongs to captions.
- **Hard offset text-shadow, not blur** — reads as paint standing off the wall.

### P5.3 Motion

⚠ **zoompan smoothness is governed by RATE, not resolution.** It crops at integer
source pixels; below ~0.8 %/second the crop repeats for runs of frames and then
jumps. Measured (std/mean of frame delta, same filter, only rate changed):

| beat length | jitter score |
|---|---|
| 6 s | 0.09 |
| 30 s | 1.09 |
| 55 s | 1.64 |

> Hold the rate fixed; let total zoom follow duration; past ~14 s hold the frame
> still. Supersampling helps and cannot fix it. **Short blocks can.**

★ **And when consecutive blocks share a plate, cut — do not dissolve.**
Cross-fading between two frames whose artwork is identical leaves both text
cards on screen at once and reads as a broken double exposure.

---

## P6. Plates per episode

~9–15 for a 10-minute episode, each covering 2–4 blocks. Reusing one plate
across a span while the text changes over it is **deliberate**: it gives the
viewer a stable image to rest on and it halves GPU time.

This is exactly `spec-studio.md` §S4.2's binding partition. **The plate count is
a consequence of the binding, not a separate decision.**

---

## P7. ⚠⚠ Verification — the rules that must not bend

**1. A missing plate is a hard error.** Never substitute. The Python pipeline had
a "use a placeholder if missing" convenience path; when the server died it built
an entire episode on another episode's artwork **and reported success**.

**2. Verify plates before rendering, not after.** Per span: generate → confirm
every file exists → retry once → abort *that span* rather than proceed.

**3. Check for silent duplicates.** After a run that reported any failure,
hash every plate. In the incident above the check was decisive: *14 plates, 14
unique hashes* proved the images were genuine and the failures spurious.

**4. Existence is not integrity.** A file of plausible size can be a truncated
PNG. Verify the signature and dimensions, not the byte count.

---

## P8. What to build, in order

1. **`PLATE_ENGINE`** deferred + `COMFY_PLATE_ENGINE` — graph in P2.2, protocol
   in P4, both failure modes in P4.1 handled from the start.
2. **Prompt assembly** — P3's three parts, with STYLE_PRE/POST as *project
   settings*, not constants. A different series may want a different medium.
3. **Ground colour as a project property** — one value driving both the prompt
   phrase and the CSS.
4. **Verification** (P7) before any batch UI exists.
5. **The compositor last.** It is the best-understood part and the least likely
   to surprise anyone.

⚠ **Do not start by porting the Python.** Read `plate.py` for the *decisions*;
the code is 120 lines and most of its value is in its comments, which record why
each number is what it is.
