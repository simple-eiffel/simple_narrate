# simple_narrate — THE STUDIO

**An amendment to [`spec.md`](spec.md).** Everything there still holds unless a
section here says otherwise. Two sections say otherwise, and both are flagged.

Status: **specification.** No code. `spec.md`'s own warning applies to this file
verbatim — nothing here has compiled, and no contract has seen `ec.sh check`.

---

## S1. What this adds, and why

`spec.md` describes a machine: essay in, narrated recording out, gated on
evidence. It is a *pipeline* with a GUI mentioned in passing.

This amendment describes the **instrument you play** — the thing that sits where
ElevenLabs Studio sits, except local, scriptable, and yours. Four additions:

| # | addition | overturns spec.md? |
|---|---|---|
| S3 | **Voice palette** — a voice per block | ⚠ **YES** — §4 declares "not multi-speaker" |
| S4 | **Plates** — artwork bound to a span of blocks | no; new territory |
| S5 | **Prosody capture** — your reading becomes markup | no; realises §18.4 |
| S6 | **Marks** — the notation, and what can honour it | extends §9, §10 |

The GUI itself (S7) is a decision `spec.md` deferred rather than a reversal.

---

## S2. ⚠ The non-goal being overturned, stated plainly

`spec.md` §4: *"**Not multi-speaker.** One narrator, one essay. No dialogue, no
character voices."*

S3 overturns that. It is a deliberate scope change requested by the author, and
it is recorded here rather than quietly absorbed, because a non-goal that
evaporates without anyone noticing is how a focused tool becomes a swamp.

**What the reversal costs, honestly:**

- Voice consistency across a long piece was §15 Phase 0's *first* kill question.
  Multi-voice multiplies it: now several voices must each hold, *and* not clash.
- Assembly gets harder. Two voices at different loudness, spliced back to back,
  is audible in a way one voice never is. §S3.4 answers this; it is real work.
- The gate (§spec 7) compares synthesized audio against source text. With mixed
  voices the round-trip still works per block, so the gate survives — but a new
  failure mode appears that it cannot see: *the right words in the wrong voice.*
  §S3.5 adds the check.

**The scope fence that keeps this from becoming a DAW.** Multi-voice here means
*one voice per block, chosen from a palette*. It does **not** mean overlapping
speakers, interruption, cross-talk, or timeline editing. Two people talking at
once is a different program.

---

## S3. The voice palette

### S3.1 The model

```
VOICE_PALETTE          a named, ordered set of VOICE_SLOTs, saved with the project
VOICE_SLOT             id, display_name, engine_ref, colour, is_default
NARRATION_BLOCK        gains: voice_id: STRING_8    -- defaults to palette default
```

A slot is a *role*, not a model file: "Narrator", "The Objector", "Larry". The
engine behind a role can change without touching a single block. This is the
same discipline `spec.md` §4 applies to models generally — *the model is a
settings value* — and it is why the palette stores an `engine_ref` rather than a
path to a `.onnx`.

### S3.2 Kinds of slot

| kind | backed by | notes |
|---|---|---|
| **synthetic** | `TTS_ENGINE` (§spec 12) | Chatterbox / Kokoro / Piper voice |
| **cloned** | `TTS_ENGINE` + a reference sample | your voice, synthesized |
| **recorded** | a WAV per block, supplied by you | **no synthesis at all** |

★ **The `recorded` kind is the important one and it is nearly free.** A block
whose voice slot is `recorded` skips the engine entirely and uses audio you
provide. That single row is what lets you read your own part of a panel while
the other parts synthesize — and it is also the whole of "use my real voice,"
which needs no cloning and no model.

⚠ **A `recorded` block cannot be re-rendered.** Everything in `spec.md` §8 assumes
a block can be regenerated from its text; a recorded block cannot. Editing its
text therefore *invalidates* rather than *regenerates* it, and the GUI must show
that state rather than silently keeping stale audio. This is a new state in the
block lifecycle and it is the most likely place for this amendment to introduce
a bug.

### S3.3 Assignment in the GUI

The palette lives at the left margin of each block, mirroring the reference
implementation: a coloured dot per block, click to reassign. Selecting several
blocks and assigning once is the common case for panel material and must not
require six clicks.

### S3.4 Loudness matching — the thing that makes it not sound amateur

Spliced voices at different levels are the tell. Before assembly, every rendered
block is normalised to a common integrated loudness. `simple_ffmpeg` was verified
in `spec.md` §13 as *partial* — transcode present, concat and silence absent —
so loudness normalisation must be assumed absent too **until someone greps for
it**, and §14.1's resolution for concat is the pattern to follow.

**Target: −16 LUFS integrated, −1.5 dBTP ceiling.** That is the spoken-word
streaming convention and it is a number, so it is checkable.

### S3.5 The gate extension

`spec.md`'s gate proves *the right words came out*. It cannot prove *the right
voice said them*, because transcription is voice-blind. So:

> **Voice-assignment invariant.** For every block, the rendered artefact's
> `voice_id` provenance equals the block's current `voice_id`. Checked on
> assembly, not on render.

Cheap, and it catches the failure that would otherwise ship: reassigning a voice
and shipping a cached render from the old one.

---

## S4. Plates — binding artwork to a span

### S4.1 Why this belongs here and not in a video tool

The narration project already knows where every block starts and how long it
runs. That is exactly the information a video assembler needs, and it is
expensive to reconstruct later. Recording *which picture is on screen for these
blocks* costs one field and turns the session file into a complete edit
decision list.

### S4.2 The model

```
PLATE            id, image_path, prompt (nullable), seed (nullable)
PLATE_BINDING    plate_id, first_block_id, last_block_id
```

Bindings **partition** the block sequence: contiguous, non-overlapping, no gaps
once complete. A partition is far easier to reason about and to render than
arbitrary spans, and it matches how the artwork is actually used — one painting
holds the screen while several blocks are spoken over it.

> **Invariant.** Bindings are ordered, contiguous and disjoint; every bound block
> belongs to exactly one binding.

`prompt` and `seed` are kept so a plate can be regenerated. They are nullable
because a plate may be a photograph or something drawn by hand, and a design
that cannot hold a hand-made image is a design that assumes its own tooling.

### S4.3 What this does not do

Not an image generator. Plates arrive as files. Whether they came from FLUX,
a camera, or a scanner is not this program's business — the same discipline
that keeps `TTS_ENGINE` behind a boundary.

---

## S5. ★★ Prosody capture — your reading becomes the markup

**This is the part that does not exist in ElevenLabs, and it is the reason to
build rather than subscribe.**

### S5.1 The problem it solves

You asked two questions: can the AI follow my reading, and can it use my voice.
The honest answer to both was *yes, but*. Cloning gives timbre and generic
delivery. Voice conversion gives your delivery but still makes you read
everything, forever, including after every script edit.

The third option neither of us named: **read a block once, and have the machine
write down what you did.** Not to copy your audio — to extract the *performance
decisions* as marks, which then apply to any voice, survive a text edit, and can
be tuned by hand afterwards.

Your reading becomes a score.

### S5.2 How, concretely

1. You read one block. `simple_audio` captures it (WASAPI, verified present).
2. `simple_speech` force-aligns your audio to the known text — word-level
   timings. It is the round-trip gate's engine, already a dependency, and it is
   doing here what it already does there.
3. The same block is synthesized in the target voice as a **baseline**.
4. **Compare.** For each inter-word gap and each word duration, the difference
   between your read and the baseline is the signal.
5. Differences that exceed a threshold become marks (§S6).

| what differs | mark emitted |
|---|---|
| your gap ≫ baseline gap | `\|`, `\|\|`, `\|\|\|` by size |
| your word duration ≫ baseline | `{slow}` around the span |
| your word duration ≪ baseline | `{fast}` |
| your pitch + energy peak on a word | `_word_` (advisory — see §S6.3) |

6. The marks are written into the block, **visibly**, where you can edit them.

### S5.3 Why this is better than it sounds

- It **survives editing.** Change a sentence and the marks around it still stand.
  A recording does not survive editing at all.
- It **transfers.** Marks derived from your read apply to any voice in the
  palette, including one that is not yours.
- It is **inspectable and arguable.** A number you can see and change beats a
  black box that "sounds more natural."
- It **degrades honestly.** If capture produces nonsense, you see nonsense marks
  and delete them. Nothing is silently baked into audio.

### S5.4 ⚠ And why it might not work

Stated up front, because this is the speculative section of an otherwise
conservative design.

- **Thresholds are unknown.** Too sensitive and every block fills with noise;
  too coarse and nothing is captured. This is empirical and needs the spike.
- **Alignment on your own reading is harder than on synthesized speech** —
  disfluency, breath, false starts. `simple_speech`'s accuracy on a real human
  read at conversational pace is *unverified*.
- **Pitch-to-emphasis is the weakest link.** §S6.3 explains why the emphasis
  mark is advisory rather than executable, and prosody capture cannot fix that.
- **It may simply be easier to mark by hand.** If capture takes longer to clean
  up than typing `||` would have, the feature has failed and should be cut.

> **Spike gate.** Prosody capture ships only if, on one real 10-minute episode,
> the marks it emits are judged better than nothing by the author. Not "better
> than perfect" — better than an empty block. If it fails that, S5 is deleted
> and the rest of this amendment stands unaffected.

---

## S6. The marks

### S6.1 The notation

Written in the block text. Stripped before synthesis. Two are advisory.

| mark | meaning | executable? |
|---|---|---|
| `\|` | short beat | ✅ real silence, ~0.25s |
| `\|\|` | breath | ✅ ~0.5s |
| `\|\|\|` | long hold | ✅ ~1.0s |
| `[[1.4]]` | exact pause, seconds | ✅ |
| `{slow} … {/slow}` | *ritardando* | ✅ span re-synthesized, spliced |
| `{fast} … {/fast}` | *accelerando* | ✅ |
| `{soft} … {/soft}` | *piano* | ⚠ approximated: gain + slight rate |
| `word{=koh-DESH}` | pronunciation | ✅ **highest value of any mark** |
| `_word_` | lean on this word | ❌ **advisory** — §S6.3 |
| `(warmly)` | delivery direction | ❌ **advisory** — for a human reader |

### S6.2 Measured, not assumed

Punctuation is a weak lever. Measured on Kokoro, one sentence, same voice:

| written as | duration |
|---|---|
| no punctuation | 4.30 s |
| **commas** | **4.28 s** — *no effect* |
| em dash | 4.38 s |
| ellipsis | 4.50 s |
| split into sentences | 4.55 s |
| `*asterisks*` | **5.38 s** — *not emphasis; the phonemizer choking* |

Two consequences. **Marks must be compiled, not passed through** — the engines
do not read SSML and mangle stray markup. And **silence must be inserted by the
pipeline**, which is what `spec.md` already does at sentence boundaries; the
marks simply extend that mechanism to arbitrary positions.

### S6.3 ⚠ Why emphasis is advisory

Neither Piper nor Kokoro can be told to stress one word. Chatterbox's
`exaggeration` knob is per-*segment*, which `spec.md` §15 correctly identifies as
"precisely the per-segment lever the splice needs" — but a segment is not a word.

The available fake — a micro-pause before the word — reads as a stutter, not a
lean.

So `_word_` is honest about itself:

- It **renders in the GUI** as underline, so you see your own intent.
- It is **carried into the source** on export, so a human reader sees it.
- It **does not change synthesized audio**, and the GUI says so — a distinct
  colour for advisory marks, so nobody wonders why it did nothing.
- ★ If a block accumulates several, that is the program telling you **this block
  wants your voice**, and the natural action is to switch its slot to `recorded`.

That is a better answer than a bad emphasis simulation, and it costs nothing.

### S6.4 The lexicon connection

`word{=koh-DESH}` is an inline override. `spec.md` §10's lexicon is the project
dictionary. Ordering, which §17.3 flags as a bug that would otherwise have
shipped: **inline beats lexicon beats engine default.** Applying the lexicon
after an inline override silently discards the more specific instruction.

For this vault the lexicon earns its place immediately — *qodesh*, *nephesh*,
*kavod*, *emunah*, *ekklēsia*, *plēroō*, Harnack, Irenaeus, Ignatius. Every one
is currently a coin flip.

---

## S7. The Studio — the GUI

### S7.1 The decision `spec.md` deferred: the native stack

**`simple_widgets` + `simple_cairo` + `simple_shaping`.** Native Eiffel
throughout, no browser runtime, no IPC boundary, one language.

⚠ **A correction, recorded because the reasoning was nearly wrong.** An earlier
draft of this section chose WebView2 and justified it with a disqualifying
claim: *simple_widgets cannot render Hebrew.* That claim was carried from a
stale note and **it is false**. `simple_shaping` exists for exactly this —
"mixed-script paragraph text (Hebrew), bidi, itemization, glyph shaping and font
fallback" — and `simple_widgets` documents the integration in as many words:
Cairo's toy text API "has no bidi, no shaping, no font fallback… Hebrew comes
out left-to-right and unjoined," which is why the shaped-text path exists.

The stack was already solved. Checking took one command; the wrong decision
would have cost an IPC boundary and a Microsoft runtime dependency for a
problem that does not exist.

★★ **And there is a shipped reference implementation: `simple_chat`.** It is
described in its own README as *"a thick `simple_widgets` application — no
browser, no WebView, no HTML anywhere,"* in which *"Hebrew reads right-to-left
inside a left-to-right pane, Greek keeps its accents, and an emoji is the same
Noto picture on every member's screen."* Two classes are the pattern to copy:

| class | what it proves |
|---|---|
| **`SW_SHAPING`** | one shaping kit per window — the lifetime and ownership model |
| **`SW_CHAT_VIEW`** | a scrolling view of shaped mixed-script text |
| **`CHAT_INPUT_BOX`** | text *entry* alongside shaped display |

`SW_CHAT_VIEW` is the Studio's block list with different content. This is not a
design to invent; it is one to follow.

**How the three divide:**

| library | job here |
|---|---|
| `simple_widgets` | windows, panels, lists, buttons, transport, focus, clipboard |
| `simple_shaping` | ‎קֹדֶשׁ‎ · ἐκκλησία · mixed-script block text, bidi and fallback |
| `simple_cairo` | painting the shaped glyph runs, block state colours, waveforms |

Cairo does no shaping and never re-measures — it paints glyph ids and positions
that `simple_shaping` produced. That separation is the ecosystem's own, and it
is the right one: measurement and painting are different jobs and conflating
them is how text rendering rots.

★ **What the native stack buys that a browser would not:** the waveform and the
playhead are Cairo drawing, not a canvas element behind an IPC hop; the session
model is the only model, with no second copy living in JavaScript; and there is
one language in the stack, so a contract violation surfaces as a contract
violation rather than as a silent `undefined`.

⚠ **The cost, narrowed by that reference.** *Displaying* mixed-script text is
solved and shipped. What `simple_chat` does not obviously prove is **editing**
it: placing a caret *inside* a shaped run, selecting across a bidi boundary, and
hit-testing a click to a byte offset. A chat input box may well be left-to-right
only, in which case the hard case is still open.

> **The one question to answer before Phase S2:** does the shaping layer expose
> **cluster-to-byte mapping**? Caret placement inside a Hebrew run and §spec 8.4's
> cursor-not-selection splitting both depend on it. Read `CHAT_INPUT_BOX` first —
> it is the nearest existing answer.

★ **A fallback that costs little if the answer is no.** Marks (§S6) are ASCII and
sit *outside* the shaped runs. The Studio could edit block text as plain
left-to-right source — where the caret problem does not arise — and render the
shaped view alongside it. Uglier, and it ships.

### S7.2 Layout — a starting point, not a specification

The reference implementation is a *target to begin from*, and the author
expects it to move. What is load-bearing is the block-as-unit-of-everything
principle below; the arrangement of panels is not.


```
┌────────────┬──────────────────────────────────────────────┐
│ PALETTE    │  ● │ Introduction: The Question Behind…       │
│  ● Narrator│  ● │ In one-twelve CE a Roman governor…       │
│  ● Objector│  ● │ ▸ marks visible, editable inline         │
│  ● Larry   │  ────────── plate: ep03_library ───────────   │
│  [rec]     │  ● │ Modern American evangelicalism…          │
│            │  ● │ Why aren't we growing…                   │
│ BLOCK      │                                              │
│  voice ▾   │                                              │
│  state     │                                              │
│  takes     │                                              │
├────────────┴──────────────────────────────────────────────┤
│  ⏮  ▶  ⏭   0:00 / 10:28      [Regenerate] [Record] [Gate] │
└───────────────────────────────────────────────────────────┘
```

Blocks are the unit of everything: selection, playback, regeneration, voice
assignment. Plate bindings render as rules *between* blocks — visible structure,
not a separate panel.

### S7.3 Block state, shown not guessed

Every block displays exactly one state, because "is this audio current?" is the
question the user asks constantly and should never have to infer:

`empty` · `rendering` · `current` · **`stale`** (text changed since render) ·
**`invalid`** (recorded block whose text changed — §S3.2) · `failed`

⚠ **`stale` must be impossible to miss.** The failure this program exists to
prevent is shipping an episode where one block's audio does not match its text.
That is precisely the class of bug that shipped a truncated MP4 and an episode
built on the wrong artwork in the video pipeline this month. The lesson
transferred: **existence is not currency.**

### S7.4 Takes

`spec.md` §18.7 chooses takes over generation history and is right. The Studio
surfaces them: N renders per block, one marked current, the rest auditionable
and deletable. Re-rendering never destroys the previous take until you say so.

---

## S8. Ecosystem — what is verified, what is not

Continuing `spec.md` §13's discipline. **Verified means someone read it.**

| library | status | used for |
|---|---|---|
| `simple_speech` | production (§13) | force-alignment for §S5 **and** the gate |
| `simple_audio` | development (§13) | capture for §S5, playback |
| `simple_widgets` | ★ **verified by reading** — documents the shaped-text path | the Studio shell (§S7) |
| `simple_shaping` | ★ **verified by reading** — bidi, itemization, fallback | Hebrew/Greek block text |
| `simple_cairo` | ★ **verified by reading** — paints pre-shaped glyph runs | painting, waveform, state |
| `simple_onnx` | ⚠ **UNVERIFIED** | possible in-process TTS, avoiding the HTTP hop |
| `simple_markdown` | production (§13) | the marks are markdown-adjacent |
| `simple_json` / `simple_toml` | production (§13) | session file |
| `simple_ffmpeg` | partial (§13) | ⚠ loudness normalisation **presumed absent** (§S3.4) |
| `simple_voice` | **stub, 461 lines, synthesizes nothing** | still the engine seat |

⚠ **One question outranks the rest: does `simple_shaping` expose
cluster-to-byte mapping?** Caret placement and block splitting inside a shaped
run depend on it (§S7.1). Check before Phase S2, not during.

**The remaining unverified rows block nothing yet and must be closed before Phase S2.**
`spec.md` §13's own lesson — *draft 1 hand-rolled four things the ecosystem
already had* — applies to this file too, and I have not yet done that reading.

---

## S9. Phasing

Slots into `spec.md` §15 rather than replacing it.

- **Phase 0 (unchanged)** — Python spike. Chatterbox. Answer the three kill
  questions. **Add a fourth: does prosody capture produce usable marks?** (§S5.4)
- **Phase 1 (unchanged)** — CLI. Session, blocks, render, assemble, gate.
  **Add:** voice_id on the block; `recorded` slots; plate bindings. All three are
  data-model work with no GUI, and doing them now avoids a migration later.
- **Phase S2 — the Studio.** Native stack (§S7.1: `simple_widgets` +
  `simple_cairo` + `simple_shaping`), block list, palette, playback,
  regeneration, takes, state display.
- **Phase S3 — capture.** Record, align, diff, emit marks. **Cuttable.** If §S5.4's
  gate fails, this phase is deleted and nothing else changes.
- **Phase S4 — the bridge.** Export the session as an edit decision list the video
  assembler consumes: block timings, plate bindings, caption cues. This is where
  the narration project stops being an audio tool and becomes the front end of
  the whole pipeline.

---

## S10. What this is still not

`spec.md` §4's other non-goals stand and are worth restating, because a program
that gains a GUI attracts feature requests:

- Not a DAW. No EQ, compression, music beds, ducking, or timeline.
- Not overlapping speakers. One voice per block (§S2).
- Not an image generator (§S4.3).
- Not a TTS or STT library — both stay behind their boundaries.
- **Not a cloud service.** Nothing leaves the machine. That is the whole point,
  and every addition above holds to it.

---

## S11. Open questions for the author

1. **Is the multi-speaker reversal (§S2) approved?** It overturns a stated
   non-goal. Everything else here is additive; this one is a decision.
2. **Is prosody capture (§S5) worth a spike?** It is the most interesting idea
   in this document and the most likely to fail.
3. **`recorded` slots may make cloning unnecessary.** If you will read your own
   parts anyway, the cloning question from earlier answers itself — you would be
   paying model complexity for something you are already doing better.
4. **Should the Studio own the plates outright?** §S4 records bindings. It could
   instead *generate* them by calling the existing FLUX pipeline — convenient,
   and a violation of §S4.3. My recommendation is to hold the boundary.
