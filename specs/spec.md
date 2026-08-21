# simple_narrate — Specification

> Draft 5 · 2026-08-21 · pre-Phase (feeds `/eiffel.intent`)

---

## 1. What this is

**An application, not a library.** It turns an essay you wrote into an audio
recording you would actually publish, running entirely on your own machine, and
it refuses to call the job done on evidence it does not have.

It is in the ecosystem because it is written in Eiffel and built on the
`simple_*` libraries — the same standing `simple_ocr_capture` has.

---

## 2. The problem it exists to solve

One 28-minute essay was narrated by hand-run Python. Three classes of failure
turned up, and **none of them were visible until someone listened**:

| failure | example | measurable? |
|---|---|---|
| Pronunciation | `Mesha → misha`, `Chemosh → kimosh`, `Mesha Stele → misha steel` | yes — round-trip catches it |
| Prosody | 17 sentences over 35 words; longest ran 60 | yes — countable before synthesis |
| Reading | a `·` separator run together; a title starting "And" losing its boundary | **no** — only the ear |
| Emphasis | `**bold**` and `*italic*` stripped by the script generator | **no** — and it was authorial signal, deleted |

And underneath all four, a cost problem: **every fix re-rendered 28 minutes.**
That is what makes iteration stop happening. Not difficulty — latency.

---

## 3. The central idea

★ **Two gates. Neither one is sufficient.**

- **The number** — round-trip fidelity. Synthesize, transcribe back with
  `simple_speech`, diff against the script. This proves *the words survived*.
- **The ear** — you listened to this block and blessed it. This proves *the
  reading is right*.

The round-trip measures intelligibility, not correctness. It cannot tell you
whether `read` was spoken as *reed* where the sentence needed *red*; it only
tells you the word came back. Equally, an ear that has heard 28 minutes will
miss a mangled proper noun in minute 19.

**Publishing requires both, and the tool tracks both as state.** That is the
whole design. Everything below is machinery in service of it.

---

## 4. Non-goals

- **Not a TTS library.** Synthesis lives behind `TTS_ENGINE` in `simple_voice`.
- **Not an STT library.** Transcription is `simple_speech`.
- **Not multi-speaker.** One narrator, one essay. No dialogue, no character voices.
- **Not a mastering suite.** No EQ, compression, music beds, or ducking.
- **Does not pick a model.** The model is a settings value, exactly as
  olmOCR-2 is a settings value in `simple_ocr_capture`. Naming a library after
  its model is how `simple_voice` ended up as 461 lines of stubs with seven model
  directories it cannot load.

---

## 5. Vocabulary

| term | meaning |
|---|---|
| **Essay** | the source `.md` you wrote and will publish as text. **Imported once, never written back.** |
| **Session** | `session.narrate` — the editable state. Blocks, identity, kinds, params, hashes, fidelity, approvals, undo history. Saved indefinitely; reopened to continue. |
| **Script** | `script.spoken.txt` — **exported, read-only.** For reading the essay aloud yourself. Not an editing surface. |
| **Block** | a paragraph. The unit you see, play, and approve. |
| **Segment** | the unit actually handed to the engine. A block with no emphasis is one segment; a block with two emphases is five. |
| **Render** | one segment's audio, content-addressed by hash |
| **Fidelity** | round-trip word agreement, per block and overall |
| **Approval** | "I listened to this block at this exact hash and it is right" |
| **Project** | a directory holding all of the above for one essay |

---

## 6. The narration project (on disk)

**Design constraint: as few files as possible.** One text file per session, one
audio deliverable, one cache directory. Nothing else on disk.

```
%APPDATA%\simple_narrate\settings.json     ONE global file: projects_root,
                                           default voice/engine, gate threshold,
                                           pacing defaults, the lexicon
                                           (convention: ocr_settings.e:4)

<projects_root>/The Leash/01 - The Day Yahweh Looked Defeated/   ← SESSION FOLDER
    session.narrate        ★ THE ONE FILE. Source text, blocks, ids, kinds,
                             per-block params, hashes, fidelity, approvals,
                             undo history. Human-readable. Kept indefinitely.
    essay.mp3              the deliverable (or essay.HOLD.mp3)
    cache/<hash>.wav       renders. Machine files. Kept indefinitely.
```

**What folded in.** `source.md` (the imported essay lives inside the session
file), `manifest.json` and `project.json` (merged), `fidelity.md` (fidelity is
already per-block data — the report is *generated on demand*, not stored), and
`script.spoken.txt` (exported on demand, not kept).

★ **The render cache stays a cloud of files — settled.** One WAV per *segment*
(a block with no emphasis is one segment; a block with two emphases is five),
ffmpeg'd into the single deliverable at the end of the cycle, once every block is
approved. A packed blob was considered and rejected: ffmpeg's concat demuxer needs
real paths, so a blob means extracting ~80 MB to temp before every assembly, and
one corrupt blob loses hours of render time.

**Cache filenames carry the block id as well as the hash** — `cache/9b21.c471de.wav`:

- the **block id** is stable, so moving a block renames nothing
- the **hash** is the cache key, so editing produces a new file rather than
  overwriting a good one
- the directory becomes browsable by block, and a block's several hashes sitting
  side by side *are* its undo history's renders

### 6.1 The session file format

**TOML, via `simple_toml`.** Array-of-tables for blocks, multi-line basic strings
for prose:

```toml
version = 1
voice   = "en-US-AndrewNeural"
engine  = "edge-tts"
gate    = 0.95

[[block]]
id       = "7f3a…"
kind     = "heading"
hash     = "a3f2c9…"
fidelity = 0.98
approved = "a3f2c9…"
text     = """
The Day Yahweh Looked Defeated
"""

[[block]]
id       = "9b21…"
kind     = "prose"
hash     = "c471de…"
fidelity = 0.94
approved = ""
exaggeration = 0.7          # per-block engine params live here (§8.1)
text     = """
And he's smart about it, too. He doesn't overreach. He doesn't claim the
whole Bible is !one long lie!.
"""
```

⚠ **Why not JSON, when `simple_json` is right there?** Prose in JSON is one long
line of `\n` escapes. A tool whose entire thesis is *human review* should not
store the human's paragraphs in a form no human can read. TOML's multi-line basic
strings keep prose as prose and diff cleanly in git beside the essays.

★ **And it costs nothing to build.** Draft 1 specced a ~200-line hand-written
parser and a mandatory round-trip property test. `simple_toml` is verified to be
a *parser and writer* — `to_toml`, `serialize`, `save_file`, `Token_ml_basic_string`
for `"""…"""`, plus Building and Querying features. The hand-written parser and
its whole risk category are deleted.

★ It also returns something draft 1 lost: **the session file is already the
reading script.** Exporting `script.spoken.txt` is a convenience, not a need.

### 6.2 Durability: autosave, atomic writes, crash recovery

⚠ **Drafts 1–3 never said when the session file is written.** That is a real hole.
A session may span days; a power cut with the model held in memory would lose all
of it.

**Every mutation autosaves.** Serialising ~200 TOML blocks is a few hundred
kilobytes and milliseconds of work — cheap enough that there is no reason to
batch it, and no "unsaved changes" state to lose.

⚠ **Never write in place.** Serialise to `session.narrate.tmp`, flush, then
rename over the original. Rename is atomic on NTFS; an in-place write that dies
halfway corrupts the only copy of hours of work. This is not optional.

★ **The undo history is already the journal.** §8.3 stores it in the session file.
So crash recovery is simply *reopen the file*: you are exactly where you were,
with the undo stack intact and yesterday's decisions still backable-out. No
write-ahead log, no separate recovery file, no second artifact — which keeps the
one-file constraint (§6) intact.

⚠ **Partial renders need the same discipline.** A render that dies mid-write
leaves a truncated WAV, and a truncated WAV is a *silent* corruption — it plays,
it just stops early, and the gate might even pass it. Render to
`cache/<name>.wav.part` and rename on success. A stray `.part` file on startup is
an interrupted render: delete it and let the hash go dirty.

**What survives a hard kill, therefore:** every block edit, split, move, and
approval up to the last operation; every completed render; the full undo history.
**What is lost:** at most one in-flight render, which re-renders.

**Renders are content-addressed, not numbered.** A segment's hash covers:

```
text + voice_id + engine_id + engine_params + the lexicon entries that
                                              actually applied to this segment
```

Three consequences, and they are the point:

- Reorder two paragraphs → **zero** re-renders. The manifest changes; the cache does not.
- Change one word → **one** re-render.
- Add a lexicon entry for `Chemosh` → only segments containing *Chemosh* go dirty.

⚠ That last one is why the hash takes the *applied* entries and not a lexicon
version number. Versioning the whole lexicon would invalidate 28 minutes every
time you proved one new word — reintroducing exactly the latency this design
exists to kill.

---

## 7. The pipeline

```
essay.md  ──►  IMPORT (once)     **bold**/*italic* → !emphasis!.
                                 Nothing stripped silently.
   ▼
SESSION MODEL  ◄─── you edit here, in the GUI ──────────┐
   │   blocks · ids · kinds · params · undo history      │
   │                                                     │
   │  SEGMENT     blocks → segments; 35-word flag;       │
   │              lexicon applied                        │
   ▼                                                     │
for each DIRTY segment:                                  │
    TTS_ENGINE.synthesize → trim, fade, normalize        │
    → cache/<hash>.wav                                   │
   │                                                     │
   │  ASSEMBLE    ffmpeg -f concat -c copy,              │
   │              with kind-based silence (§8.6)         │
   ▼                                                     │
block audio ──► PLAY ──► you listen ─────────────────────┘
   │                     approve, or edit and loop
   │  GATE        simple_speech transcribes each BLOCK, diff vs text
   ▼
essay.mp3     only if every block approved AND fidelity ≥ gate
              otherwise essay.HOLD.mp3
```

★ Note the loop closes on **you**, not on the gate. The gate is a second,
independent condition — §3.

---

## 8. Two levels: block and segment

| | **Block** | **Segment** |
|---|---|---|
| is | a paragraph | a span sent to the engine in one take |
| you | see it, play it, approve it | never see it |
| cached | no — assembled from segments | yes, by hash |
| gated | **yes** — fidelity measured here | no |

⚠ **The gate runs on blocks, not segments, and this matters.** An emphasis
segment is often one word — `pastor`. Handed to an STT engine with no
surrounding context, a lone word round-trips badly *by nature*, and a
per-segment gate would report a failure that does not exist. Assemble the block
first, then transcribe.

**Approval is a hash, not a flag.** Each block stores `approved_hash` — the hash
you last listened to and blessed. When the block's current hash differs, the
block is dirty and needs re-listening. That is the ElevenLabs loop expressed as
state rather than as a habit: edit → dirty → re-render → play → approve.

### 8.1 Identity: two keys, two jobs

| key | is | changes when | carries |
|---|---|---|---|
| **block id** | stable identity, assigned once | never | approval, kind, per-block params, **seed**, position |
| **content hash** | the render key | text, voice, engine, params, **seed**, or applied lexicon changes | the cached WAV |

⚠ **The seed is not optional, and drafts 1–4 missed it.** Content addressing
assumes *same input → same output*. Neural TTS is **stochastic**: render the same
sentence twice with no seed and you get two different performances. Without a
seed pinned in the block state and folded into the hash, the cache is not a cache
— it is a record of one lucky roll that can never be reproduced.

ElevenLabs exposes `seed` (0 – 4,294,967,295) and is careful to say determinism is
*"not guaranteed"* — a best effort. Local models running fixed weights on one GPU
can generally do better than that, but the honest posture is theirs: treat a
reproduced render as expected, not guaranteed, and never delete a cached file on
the assumption it can be regenerated.

★ **And the seed turns out to be a feature, not just a correctness fix: it is a
take number.** Same text, different performance. "Give me another reading of that
paragraph" costs one integer — see §16.5.

⚠ **This reverses an earlier draft**, which argued against explicit block ids on
the grounds that machine syntax in a hand-edited file destroys hand-editability.
That reasoning was correct *for a hand-edited file*. The editing surface is the
GUI over the session model, so the objection is void.

★ **What ids buy that hash-matching could not: per-block settings survive edits.**
Want one paragraph read hotter? That is a block-level engine parameter. Fix a typo
in that paragraph and the hash changes and the render is redone — but the id
persists, so the setting is still attached. Under hash-as-identity, that setting
would have died with the old hash.

### 8.2 Operations

Real operations on the session model, not side effects of editing a text file:

| operation | renders |
|---|---|
| `move_up` / `move_down` | ★ **0** |
| `set_kind` (pacing only) | ★ **0** — padding is applied at assembly, not baked into a render |
| `delete` | 0 |
| `merge` | 1 |
| `edit_text`, `set_params` | 1 |
| `split_at` (cursor) | 2 |
| `split_out` (selection mid-block) | 3 |

**Move costs nothing.** No block's text, voice, or parameters change, so every
hash matches. Cache hits, approvals survive, only order changes.

*Does approval survive a move?* Yes. The block's audio is byte-identical, and
approval is a judgement about the block's **reading**, not its position. If
reordering changes your judgement about the sequence, that belongs to the full
listen, not the block gate.

### 8.2.1 Why split cannot be free — going forward

⚠ **Split costs both halves, and this is not a cache limitation.** It is a fact
about speech. `ABCDEF` spoken as one take carries no sentence-final fall at the
`C|D` boundary; spoken as two it does, and the second take starts cold instead of
carrying momentum from the first. The audio *must* differ, so the cache *must*
miss.

★ **But undo is free** — see §8.3. Split, dislike it, undo: the original block's
hash returns, its render is still in `cache/` (kept indefinitely, §18.6), and its
approval comes back with it. **Zero re-render.** So the cost of experimenting is
two renders forward and nothing to back out. The claim "split can't be free"
holds only in the forward direction.

### 8.3 Undo and redo

**No `simple_*` library provides this.** Searched: no `simple_undo`,
`simple_command`, or `simple_history`; the grep hits were `"This cannot be
undone."` in an OCR dialog and `ReDoS` in `simple_regex`.

★ **ISE ships the abstraction, though** — `UNDO_CMD` in
`library/editor/text_window/text/undo/undo_cmd.e`. Sixty lines, deferred,
**zero editor dependencies**: `undo` and `redo` deferred behind `undo_possible` /
`redo_possible` preconditions, plus `is_bound_to_next`, which groups several
commands into a single undo step. That last one is exactly the
"coalesce a multi-step operation" problem, already solved.

⚠ **Take the shape, not the dependency — and the reason is the code, not a rule.**
CLAUDE.md's "only ISE `base`, `time`, `testing`" is justified there by *"no
`simple_*` equivalent exists,"* which is true here, so the rule would permit it.
The code does not:

- `UNDO_REDO_STACK` is 652 lines with nearly every feature exported
  `{EDITABLE_TEXT}`. `NARRATE_SESSION` cannot call it at all.
- `UNDO_CMD` is **pure deferred signature** — there is no implementation to
  inherit. The dependency would buy a signature and cost a coupling to
  EiffelStudio's internal editor library, which is not a published reusable
  library and can shift between releases.

Reimplement its sixty lines locally (Eiffel Forum License v2), keeping
`is_bound_to_next`.

**The history is a data structure, not a framework.** `TWO_WAY_LIST` from
EiffelBase with `index`, `forth`, `back`, and truncate-after-index gives the whole
discipline. One deferred command class plus one list is the entire facility.

### 8.3.1 Build it here, promote it later

The ecosystem choice for a genuine gap is *use ISE as-is* or *build a `simple_*`
library covering it*. Here the first is unavailable (the stack is welded shut), so
the answer is the second — **`simple_undo`**, and it earns its place: any editing
GUI needs it, the contracts are subtle enough to be worth getting right once, and
a modern version improves on ISE's meaningfully.

★ **The modernity that justifies it:** ISE needs a class per undoable operation —
`UNDO_DELETE_CMD`, `UNDO_INSERT_CMD`, `UNDO_REPLACE_CMD`, and so on. With agents,
one concrete command class suffices:

```eiffel
create cmd.make (agent do_split (blk, off), agent undo_split (blk, off))
```

That collapses this app's ~8 operations from eight classes to eight calls. Add
void safety, SCOOP compatibility, generic constraint on the target, and a
serialisable history (§8.3 requires undo to survive reopening) and it is a real
library rather than a copy.

★ **Decided: built inside `simple_narrate` first; `simple_undo` goes on the
post-`simple_narrate` agenda.** `simple_voice` is the counter-example sitting in
this same ecosystem — a library designed in the abstract, 461 lines of stubs,
seven downloaded model directories, no consumer to force the API honest. An API
that has survived eight real operations in a working app is worth extracting; one
that has survived a design session is not.

⚠ Extraction is only cheap if it is planned for. Keep the command classes free of
narration concepts — a command knows how to do and undo *something*, not that the
something is a block. If `UNDO_COMMAND` ever mentions `NARRATE_BLOCK`, the
promotion has already failed.

```
invariant  history_index >= 0 and history_index <= history.count
require    can_undo    -- history_index > 0
require    can_redo    -- history_index < history.count
```

Undo history is stored in the session file and **survives reopening** — you can
close an essay mid-massage and back out yesterday's decisions tomorrow.

### 8.4 Splitting in the GUI: cursor, not selection

★ **The cursor is the input. The highlight is the tool's output.**

Place the caret and the GUI tints everything above it in one shade and everything
below in another — you *see* the two blocks you are about to get, before
committing. One click, no selection.

That answers the worry directly: the failure you named — a selection that didn't
quite reach the top or the end — **cannot occur, because you never make a
selection.** The tool draws the boundary you'd have had to draw by hand.

Selection-split stays for the three-way case, where two boundaries genuinely are
needed, with the same preview in three tints.

⚠ The tool **warns but does not block** on a mid-sentence split. Both halves take
sentence-final intonation and it will sound wrong — but it is your cadence, the
same standing as the 35-word rule. **Suggested affordance:** when the caret lands
within a few characters of a sentence boundary, offer to snap to it. Offer, not
force.

### 8.5 Two kinds of splitting — do not conflate them

|  | **block split** | **sentence split** |
|---|---|---|
| what | one paragraph becomes two | a 60-word sentence becomes two sentences |
| how | a boundary between blocks | rewriting — a full stop, maybe a conjunction |
| who | the tool performs it | **you write it**; the tool only flags |

⚠ The 35-word rule flags a sentence *inside* a block. **You cannot fix it by
splitting the block** — the boundary would land mid-sentence, which is the warned
case above. The fix is editing words. These are different operations that both
happen to be called "splitting."

### 8.6 Block kinds and pacing

| kind | lead silence | trail silence | why |
|---|---|---|---|
| `prose` | none | short | the ordinary beat between paragraphs |
| `heading` | long | medium | a reader pauses before a section, and again after naming it |
| `separator` | long | long | the `·` case from the first essay — a run of titles read as one sentence |

★ **Silence is inserted at assembly, not baked into a render.** Three consequences:
padding is not part of the content hash; changing a block's kind or retuning a
pause costs **zero** re-renders; and assembly stays a lossless `-c copy` concat
with generated silence files in the list. Tune the pauses by ear, instantly.

⚠ The default durations are guesses until the spike. "Natural reading pace" is an
ear judgement and nothing in the design can settle it.

**One edge case that looks like a bug and is not:** two identical blocks — a
repeated refrain — share a content hash and therefore one cached render, and
approving one approves both. Correct: it is the same audio. Their *ids* remain
distinct, so they move, split, and carry settings independently.

---

## 9. Emphasis

Your essays already encode stress as `**bold**` and `*italic*`. The current
Python strips it with a blanket `re.sub`, then asks how to infer it back. **Stop
stripping it.** Parse converts it to `!word!` — your own notation — and the
script carries it visibly. This makes `.spoken.txt` useful as a *reading* script
if you narrate one yourself, which is worth more than the synthesis case.

⚠ **What the engines can actually do with it — stated honestly, because the
answer is "less than you want":**

| backend | emphasis mechanism | reality |
|---|---|---|
| edge-tts | none | SSML is escaped at the source (`escape(remove_incompatible_characters(text))`). Markup is read aloud tag by tag. Verified: a 3.6s line became 29.4s of `"Speak version equals 1.0 XML…"`. Punctuation buys a pause; nothing buys stress. |
| local neural | per-utterance conditioning | no per-word dial exists. Emphasis is achieved by **splicing**: the emphasized span is its own take with hotter parameters, crossfaded back in. |

★ The control you want and the naturalness you want come from opposite
architectures. Old engines expose per-word prosody *because* they assemble
speech from parts — which is why they sound assembled. Neural engines sound
human *because* nothing assembles them — which is why there is no seam to reach
into. **No free engine has both.** The splice is a workaround with real costs:
seam artifacts, and voice drift between takes.

`simple_narrate` owns the splice. `TTS_ENGINE.synthesize` takes **one** segment
and returns **one** buffer — as thin as `ocr_engine.recognize`. Adding a
backend must never mean reimplementing assembly.

---

## 10. The lexicon

Two tiers, and the distinction is the whole value:

- **Candidate** — a respelling someone guessed. Recorded, never trusted.
- **Proven** — a respelling that was synthesized, transcribed back, and returned
  the intended word. Earned, durable, reusable across every future essay.

`Van Hooser` cost real time to prove. `Mesha` and `Chemosh` have not been proven
and are logged as candidates. Proving one is expensive; proving it twice is
waste. The lexicon is **global**, with per-project overrides.

> **invariant:** every entry in the proven tier carries the round-trip evidence
> that promoted it. *Prove, don't guess* becomes a class invariant rather than a
> comment in a JSON file.

---

## 11. Contracts

| where | contract |
|---|---|
| parse | `require not is_stub` — refuse to narrate a filing note |
| parse | `ensure emphasis_preserved` — markers in ⇒ markers out |
| segment | `require no_unfilled_respell_slots` — the script is reviewed before it is spoken |
| segment | `require longest_sentence <= max_words` (35) |
| render | `require segment_is_dirty` — never re-render a clean hash |
| render | `ensure cache_hit_or_fresh_render` |
| assemble | `require every_segment_rendered` |
| gate | ⚠ ~~`ensure fidelity >= gate_threshold`~~ — **wrong; see §18.8** |
| publish | `require is_publishable` — a query, not an inlined condition (§18.8) |
| lexicon | `invariant proven_entries_have_evidence` |
| lexicon | `invariant order_is_total` — §16.3 |
| block | `invariant approval_is_definitional` — §18.1 |
| session | `invariant persisted` — autosave enforced by the class, §18.2 |

> **§18 is the full contract layer**, written class by class with frame
> conditions, loop variants and check assertions. This table is the summary that
> preceded it, kept because it records where each obligation first appeared.
>
> ⚠ Two rows are struck because writing §18 proved them wrong: a contract that
> guards bad *content* rather than a bad *call* vanishes from a lean release
> binary, and must be a validation with a companion query.

**On gate failure the MP3 is still written — under `essay.HOLD.mp3`.** You need
to hear it to diagnose it; your ear caught the `·` run-on before the number did.
But it can never be mistaken for shippable, and it cannot be dragged into
Substack by accident.

---

## 12. The engine boundary

`TTS_ENGINE` — deferred, in `simple_voice`. The existing Qwen stubs come out;
the name stays; the model leaves the description.

```
synthesize (a_segment: NARRATION_SEGMENT; a_out_path: PATH): BOOLEAN
last_error: STRING_32
last_duration_ms: INTEGER
```

Effective backends:

- **`EDGE_TTS_ENGINE`** — free, no key, works today. The known-good baseline and
  the thing that still ships an essay when a CUDA update breaks Python on a Sunday.
- **`LOCAL_TTS_ENGINE`** — HTTP + JSON to a local server on `localhost`, exactly
  as `ocr_engine` → `ocr_http` → Ollama. The model runs on the 5070 Ti. Eiffel
  never sees Python.

Both free. No paid backend is specified.

---

## 13. Ecosystem dependencies — verified, not assumed

| library | verified by reading it | used for |
|---|---|---|
| `simple_speech` | **production** — `engines/`, `pipeline/`, `batch/`, `async/`, `wav_reader.e` | the round-trip gate |
| `simple_hash` | ★ **covers it** — `sha256` with `deterministic` postconditions and an MML `bytes_model` | the content hash. That postcondition *is* what content-addressing rests on. |
| `simple_toml` | ★ **covers it** — "TOML v1.0.0 compliant parser **and writer**"; `Token_ml_basic_string` in the lexer; `to_toml` / `serialize` / `save_file`; Building and Querying features | `session.narrate` (§6.1) |
| `simple_diff` | ★ **covers it** — `diff_engine`, `diff_hunk`, `diff_result`, `patch_applier` | the round-trip fidelity diff **and** source re-import (§18.8) |
| `simple_ffmpeg` | **partial** — `is_available`, `probe`, `transcode_with_options` (`FFMPEG_OPTIONS` takes `libmp3lame`), `extract_audio` | MP3 encode ✅. **Concat and silence absent** → §14.1 |
| `simple_markdown` | `md_inline_processor.e` | import: `**bold**` / `*italic*` → `!emphasis!` |
| `simple_uuid` | `simple_uuid.e` | block ids (§8.1) |
| `simple_audio` | development — WASAPI, `AUDIO_BUFFER` (PCM 8/16/24/32), WAV load | per-block playback in the GUI |
| `simple_voice` | **stub** — 461 lines, synthesizes nothing | to become `TTS_ENGINE` |
| **undo / redo** | ⚠ **absent from all ~130 libraries** | → §8.3 |

⚠ **Draft 1 hand-rolled four of these.** A 200-line session-file parser, a raw
`simple_process` shell-out to ffmpeg, an unspecified hash, and an unspecified
diff — all already covered. The lesson is the ecosystem-first check comes *before*
the design decision, not after.

---

## 14. Known gaps and risks

⚠ **`simple_audio` cannot join or encode.** Grep for `mp3|lame|concat|crossfade|mix`
across its `src/` returns nothing. **`ffmpeg` closes both gaps** — see §14.1. The
residual risk is a dependency on one external binary, which is the same shape as
`simple_ocr_capture`'s dependency on a running Ollama.

### 14.1 Assembly and encoding — resolved

Three ways `ffmpeg` joins audio, and only one scales to ~200 segments:

| method | verdict |
|---|---|
| `-f concat -c copy` | ★ instant and lossless — **requires identical codec params across all inputs** |
| `concat` filter | works, but re-encodes 28 minutes on every assembly |
| `acrossfade` filter | ⚠ **pairwise only.** 200 segments means nesting 199. The filtergraph explodes. |

**Therefore: normalize per segment at render time, where it caches.** On its way
into `cache/<hash>.wav`, each segment gets trimmed of leading/trailing silence, a
5 ms fade at each edge, and a forced uniform format. Assembly is then a list file
and `-f concat -c copy`.

**`simple_ffmpeg` is the vehicle, not a raw shell-out.** Verified: `is_available`,
`probe`, `transcode_with_options` with `FFMPEG_OPTIONS.audio_codec` accepting
`libmp3lame`. **MP3 encoding is covered.** Two features are missing and this is
where they belong — extending an existing `simple_*` library to cover the gap
rather than reaching around it:

```
concat_demux (a_inputs: LIST [PATH]; a_output: PATH): BOOLEAN
        -- Lossless -f concat -c copy join. Requires uniform inputs.
generate_silence (a_ms: INTEGER; a_output: PATH): BOOLEAN
        -- For kind-based lead/trail padding (§8.6).
```

Both are small, general, and useful to anything else that assembles audio.

- The expensive work happens once per segment and is cached with the audio.
- Uniformity is guaranteed **by construction**, so the lossless join cannot drift.
- The seam is masked by a *ramp over trimmed silence*, not an overlap. A true
  crossfade between two spoken segments would slur the last word into the first —
  worse than the seam it fixes.

⚠ The concat demuxer's list file is fragile with apostrophes and spaces in paths.
Cache filenames are hashes (`cache/a3f2c9….wav`). Content-addressing already
solved this.

> **invariant:** every cached render shares one sample rate, channel count, and
> bit depth. The `-c copy` join depends on it.

**Deferred alternative (Path B).** Trim, fade, and append are ~80 lines of int16
buffer math on `AUDIO_BUFFER` — contractable, no external process. MP3 encoding
is the genuinely hard part and the only piece worth shelling out for. Not now:
the spike is Python and uses `ffmpeg` regardless, and Eiffel buffer math written
before the spike reports on splice quality is work spent on a design that may not
survive.

⚠ **Blackwell.** The RTX 5070 Ti is `sm_120` and needs CUDA 12.8+ with torch
2.7 or newer. Many TTS repos still pin torch 2.1 / cu121 and fail to launch with
a cryptic kernel error. Budget the spike's first afternoon for dependency
archaeology, not for the model.

⚠ **Splice seams and voice drift.** Unquantified. This is the spike's job.

~~**Two editors, one file.**~~ **Retired.** This risk existed only while a
hand-edited text file was the editing surface. The session model closed it: the
GUI is the only writer, and nothing else has reason to open `session.narrate`.

⚠ **Source drift.** The essay is imported once and never written back (§6). If
you revise `.md` in Substack after importing, the session does not know. A
re-import path is needed that diffs incoming text against the session's blocks and
preserves approvals on the blocks that did not change — the same hash reconcile,
pointed at an external source. Not yet specified.

~~**A hand-written parser is a hand-written parser.**~~ **Retired** — `simple_toml`
is a verified parser *and writer* (§6.1). A round-trip test is still worth having,
since the session file is the only place hours of work live, but it now guards a
library rather than 200 lines of new code.

⚠ **The gate is blind to stress.** By construction. §3 is the mitigation.

⚠ **Knowledge cutoff.** Model recommendations are as of May 2026 and this field
moves monthly. Verify before committing a weekend.

---

## 15. Phases

**Phase 0 — Python spike (`spike/`). No Eiffel exists yet.**
Run the whole 28-minute essay through one candidate. Answer three questions,
each of which can kill the design:

1. Does the voice hold for 28 minutes, or drift?
2. Does spliced emphasis sound like a person leaning on a word, or like a splice?
3. What is the wall-clock cost of one block re-render? *(This sets whether the
   interactive loop in §8 is pleasant or unusable.)*

First candidate: **Chatterbox** — MIT, ~6 GB so 16 is comfortable, its
`exaggeration` knob is precisely the per-segment lever the splice needs, and it
is deployed widely enough that the Blackwell problem is likeliest already solved
by someone. Fallback if long-form consistency is the binding constraint:
**VibeVoice-1.5B**.

**Phase 1 — CLI.** Session file read/write, block model, render cache, assembly,
gate, report. Headless and scriptable: *import an essay, render every block, gate
it, produce `essay.HOLD.mp3` and a fidelity report.*

⚠ **Be clear-eyed about what Phase 1 is not — and about what that does *not*
mean.** The limitation is that a command line has no way to *make* an interactive
edit: no caret to place, no selection to preview, no block to play back. Phase 1
therefore delivers **a first draft and a report**, not the massage loop. The loop
is Phase 2.

**This is not a statement about persistence.** Saving edits as work progresses is
handled in §6.2 and is not a phase concern: autosave on every mutation, atomic
rename, undo history doubling as the recovery journal. Phase 1 builds that
machinery; Phase 2 drives it. Nothing waits for the GUI to become durable.

The CLI is still worth building — it is the engine of record, and an unattended
full re-render is genuinely useful — but it is not, on its own, the product.

**Phase 2 — GUI.** `simple_vision` / EV_GRID over the same session model. Per-block
play, re-render, approve; split at cursor with live preview; move up/down; undo and
redo; dirty blocks marked; fidelity per block. **This is where the product lives.**
Nothing new is invented — §6 and §8 already contain the state model, which is why
the CLI must not become a god object that resists wrapping.

⚠ Synthesis is slow enough to freeze a Vision2 event loop, exactly as OCR was
(`ocr_engine.e` note: *"can exceed 45 seconds on a cold model load"*). Phase 2
inherits the detached-worker + polling pattern. Assume it from the start.

---

## 16. Measured against ElevenLabs

ElevenLabs is the reference implementation for this exact workflow, and reading
their docs found three assumptions in drafts 1–4 that were simply wrong, plus two
capabilities worth copying outright.

### 17.1 Request stitching — the answer to the seam problem

★ **The single most valuable find.** Their `convert` endpoint takes:

| parameter | what it does |
|---|---|
| `previous_text` / `next_text` | the text on either side of this chunk, used to condition prosody |
| `previous_request_ids` / `next_request_ids` | **max 3 each**; condition on actual prior *generations* rather than text |

Their own documentation describes precisely our workflow: *"if you have generated
3 speech clips and want to improve clip 2, passing the request id of clip 3 as a
`next_request_id` and that of clip 1 as a `previous_request_id` will help maintain
natural flow."* That is block-by-block regeneration, and continuity is the problem
they had to solve to make it usable.

**What we can take.** `previous_request_ids` depends on server-side state (their
ids expire after two hours) and has no local analogue. But `previous_text` /
`next_text` is **model-agnostic**: synthesise *context + segment + context* and
cut the segment back out. Every local model can do that today.

⚠ **And it changes the cost model in §8.2, honestly.** If a render is conditioned
on its neighbours, the content hash must include the neighbour text — so editing
block *N* dirties *N−1* and *N+1* as well. One render becomes three.

**Therefore it is a setting, not a default:** *seam quality vs. re-render cost.*
Off while drafting, on for the final pass.

### 17.2 Character-level alignment

Their `with-timestamps` endpoint returns `alignment` and `normalized_alignment`,
each carrying `characters`, `character_start_times_seconds`, and
`character_end_times_seconds`.

Two uses, and the second is the larger:

1. It is what makes §16.1's cut-the-middle trick precise.
2. ★ **It upgrades the gate from a word count to a measurement.** See §17.4.

⚠ We get no alignment from a local TTS model — but we do not need it from that
side. `simple_speech` is Whisper-based and already produces timestamped segments.
**The alignment we need is on the transcription side, and we already have it.**

### 17.3 Pronunciation dictionaries — and an ordering bug we would have shipped

They support `.pls` (XML) dictionaries with **two rule kinds**, and the
distinction is one our §10 lexicon collapsed:

- **alias** — replace the word with one the model already says correctly. This is
  respelling; it is what we do; it is all a local model will accept.
- **phoneme** — IPA or CMU Arpabet, exact, *"no room for interpretation."*

⚠ **The detail that matters most is procedural**, not phonetic: *"the dictionary
is checked from start to end and only the very first replacement is used"*, and
PLS files are **case sensitive**. Our §10 never specified application order — and
without a deterministic order, the same text can produce different substitutions
and therefore different hashes. **Content addressing silently breaks.**

> **§10 amendment.** The lexicon is an *ordered* list. First match wins. Matching
> is case-sensitive. `invariant lexicon_order_is_total`.

### 17.4 Studio: lock, and generation history

Their long-form editor is what Larry described from memory, and it has two
concepts our spec lacked:

- **Lock paragraph** — once satisfied, lock it against further change. That is
  stronger than our `approved_hash`, which *records* a judgement; a lock
  *enforces* it.
- **Generation history** — restore and download previous versions.

★ It also independently confirms a rule we derived ourselves: *"we recommend you
regenerate a complete phrase or sentence at a time."* Their mid-sentence guidance
matches §8.4's warning, arrived at from first principles about sentence-final
intonation.

### 17.5 What ElevenLabs confirms about the ceiling

⚠ Two constraints in their own product are strong external evidence for §9's
claim that expressiveness and control come from opposite architectures:

- **`eleven_v3` has the audio tags** — `[whispers]`, `[laughs]`, `[sarcastic]`,
  inline IPA as `/ˌbaɪoʊˈkemɪstri/` — and **v3 does not support request
  stitching.**
- **v3 also drops SSML `<break>`**, which v2 supports; pacing must be done with
  ellipses and text structure instead.

So the most expressive model in a commercial product loses continuity control and
explicit pauses. The trade is not an artifact of free models. It is the shape of
the technology, and a paid subscription does not buy past it.

For emphasis their published levers are **capitalisation**, **ellipses**, and
punctuation — the same suggest-don't-instruct situation §9 describes.

---

## 17. Beyond both

Everything in §17 is catching up. This section is where the design has something
ElevenLabs does not.

### 18.1 There is no gate

★ ElevenLabs gives you controls and never tells you whether the output was
*correct*. There is no verification loop in the product — nothing transcribes the
result and checks it against the script. §3's two gates have no counterpart.

### 18.2 A lexicon that proves itself

Their dictionaries are **hand-authored and unverified**. You write IPA, you hope.
Ours promotes an entry only after synthesis and round-trip return the intended
word (§10). That distinction — *candidate* vs *proven* — appears to be original.

### 18.3 ★★ The dictionary that authors itself

**Push it further, and this is the strongest idea in the spec.** If
`Chemosh → kimosh` fails the round-trip, the tool does not have to ask a human for
the next guess. It can **generate candidate respellings and round-trip each one
until one survives.**

```
                 ┌────────────────────────────────┐
  failed word ──►│ generate N orthographic variants│
                 │  keh-MOSH · kemosh · kem-awsh   │
                 └───────────────┬────────────────┘
                                 ▼
                     synthesise each · transcribe back
                                 ▼
                    keep any that return the target
                                 ▼
                      promote the shortest survivor
```

The round-trip gate is already the fitness function. The search is embarrassingly
parallel, runs unattended, and costs GPU time rather than attention. **A human
guesses respellings one at a time; this tries forty overnight.**

⚠ It cannot invent a pronunciation the model is incapable of — the search can come
back empty, and must say so rather than promote a near-miss.

### 18.4 ★★ Prosody measured, not merely counted

The current gate compares *words*. With timestamps from `simple_speech` it can
compare **delivery**:

| measurable | catches |
|---|---|
| words per minute, per sentence | rushing |
| silence at sentence boundaries | the `·` run-on from the first essay — **directly** |
| longest unbroken speech run | the 60-word sentence, *as delivered* rather than as written |
| duration of a block vs. its word count | a block the model raced or dragged |

★ The `·` separator failure — the one caught by ear, the one §2 classified as
*not machine-detectable* — **becomes detectable.** Three titles run together as
one sentence means no inter-title silence, and silence is a number.

That reclassifies one of the four original failure modes from "only the ear" to
"measurable," which is the single biggest improvement available to this design.

### 18.5 ★★ Verifying emphasis — attacking the stated limit

§9 concedes the gate is blind to stress. That concession may be too generous.

An emphasised word should be **longer and more prominent** than the same word
delivered flat. Both are measurable from the rendered audio: word duration from
the alignment, and F0 excursion or energy from the waveform. So `!pastor!` can be
checked — *did that word receive more duration and pitch movement than the block's
baseline?*

```
ensure emphasis_landed:
    across emphasised_words as w all
        w.duration > baseline_duration (w.text) * emphasis_ratio
    end
```

⚠ **Speculative, and flagged as such.** English contrastive stress is carried
mainly by pitch accent, not loudness, so this is an approximation and will produce
false negatives. But "approximate signal" beats "no signal", and it converts the
splice-quality question from a matter of taste into something with a number
attached.

### 18.6 ★★ The lexicon as a regression suite

★ Once every proven entry carries its round-trip evidence (§10's invariant), the
lexicon becomes **a test suite for the voice pipeline itself.**

Change the model, the voice, or the engine, and re-run every proven entry against
the new configuration. Whatever still returns its target still holds; whatever
does not is flagged before it reaches an essay.

**This makes switching models safe** — the thing that is otherwise terrifying about
a field that turns over monthly. Nothing in ElevenLabs does this, because nothing
in ElevenLabs knows whether an entry ever worked.

It is also the purest DbC move in the design: an invariant re-checked when the
environment changes.

### 18.7 Takes, not history

★ Combine §8.1's seed with §16.4's generation history and you get something better
than either: **each block owns a list of takes**, each a seed with its own render,
fidelity score, and prosody measurements. Audition them, compare the numbers,
choose one. Approval points at a take.

ElevenLabs' generation history is linear — a stack of previous versions. Takes are
a *set* you choose from, with the gate's measurements attached to each. And they
cost nothing extra: the renders are already cached, already content-addressed, and
already kept indefinitely.

---

## 18. The contract layer

⚠ **Nothing below has been compiled.** These are specification contracts written
to be carried into the generated code, not verified Eiffel. They need an
`ec.sh check` pass before any of them can be claimed to hold.

The aim is that the contracts do the specifying, so implementation is constrained
rather than merely guided.

### 19.1 The definitional invariant, and why it matters most

★ The highest-value contract in the design is one line, and it makes an entire
category of bug unrepresentable:

```eiffel
class NARRATE_BLOCK

invariant
    approval_is_definitional:
        is_approved = (attached approved_take as t and then
                       t.hash.same_string (content_hash))
```

`is_approved` is not a flag some command must remember to clear. It is *defined*
as "the take I blessed is the take that is current." Edit the text, the hash
changes, and **the block un-approves itself** — not because `edit_text` was
careful, but because approval was never an independent fact.

Draft 2 described this behaviour in prose and would have implemented it as a step
inside every mutator. As a definitional invariant it cannot be forgotten by a
mutator that does not exist yet.

The rest of the class:

```eiffel
feature -- Access
    id:            UUID                    -- stable for life
    kind:          BLOCK_KIND              -- prose | heading | separator
    text:          STRING_32
    seed:          NATURAL_32
    params:        ENGINE_PARAMS
    takes:         ARRAYED_LIST [NARRATE_TAKE]
    approved_take: detachable NARRATE_TAKE

invariant
    id_never_empty:       not id.is_empty
    text_not_blank:       not text.is_whitespace
    hash_is_derived:      content_hash.same_string (computed_hash)
    seed_pinned:          seed > 0
    takes_seeds_distinct: across takes as t all
                              occurrences_of_seed (t.seed) = 1
                          end
    dirty_definitional:   is_dirty = not cache.has (content_hash)
```

⚠ `seed_pinned: seed > 0` is the §8.1 discovery placed where it cannot be skipped.
A block with no seed is not a valid block, because its render is not reproducible,
because the cache would then be a lie.

### 19.2 The session, and autosave as an invariant

```eiffel
class NARRATE_SESSION

invariant
    ids_unique:         across blocks as b all
                            occurrences_of_id (b.id) = 1
                        end
    history_index_sane: history_index >= 0 and history_index <= history.count
    can_undo_defined:   can_undo = (history_index > 0)
    can_redo_defined:   can_redo = (history_index < history.count)

    persisted:          not has_unsaved_changes
```

★ **`persisted` is §6.2's durability discipline stated as a class invariant.**
Eiffel checks invariants on exit from every exported feature, so a command that
mutates the session and fails to write it out violates the class. Autosave stops
being a habit each command must observe and becomes a condition the class will not
permit anyone to break.

### 19.3 Commands: frame conditions, and cost claims made checkable

★ The design's performance claims are postconditions. If move is genuinely free,
say so somewhere it can fail.

```eiffel
move_block_up (a_index: INTEGER)
    require
        in_range: a_index > 1 and a_index <= blocks.count
    ensure
        swapped_up:       blocks [a_index - 1] = old blocks [a_index]
        swapped_down:     blocks [a_index]     = old blocks [a_index - 1]
        count_preserved:  blocks.count = old blocks.count
        nothing_rendered: renders_performed = old renders_performed
        approvals_intact: across blocks as b all
                              b.is_approved = old approval_of (b.id)
                          end
        others_untouched: across blocks as b all
                              (b.index /= a_index and b.index /= a_index - 1)
                              implies b.content_hash ~ old hash_of (b.id)
                          end
        undoable:         can_undo
```

`nothing_rendered` is §8.2's headline claim. `others_untouched` is the frame
condition — the statement of what this command does *not* disturb, which is the
half of a specification that usually goes unwritten and is exactly where
regressions live. (`simple_mml` and the `eiffel-mml` skill exist for expressing
these as model queries; this design should use them rather than hand-rolling
`old` comparisons.)

```eiffel
split_at (a_block: NARRATE_BLOCK; a_offset: INTEGER)
    require
        present:       blocks.has (a_block)
        offset_inside: a_offset > 0 and a_offset < a_block.text.count
    ensure
        count_grew:      blocks.count = old blocks.count + 1
        text_conserved:  joined_text.same_string (old joined_text)
        both_unapproved: not upper_half.is_approved and
                         not lower_half.is_approved
        cost_is_two:     pending_renders = old pending_renders + 2
```

★ `text_conserved` earns its keep. A split must neither lose nor invent a
character — a failure nearly invisible by eye across two hundred blocks, and
instant under a postcondition.

⚠ **`cost_is_two` becomes `cost_is_six` when context conditioning (§16.1) is on**,
because the neighbours are re-conditioned too. Writing the postcondition against
the setting rather than a constant is itself a forcing function: it makes the
price of that feature impossible to overlook.

### 19.4 What is deliberately *not* a precondition

★ A precondition removes the caller's authority. Two rules here are deliberately
queries instead:

```eiffel
splits_mid_sentence (a_block: NARRATE_BLOCK; a_offset: INTEGER): BOOLEAN
sentences_over_limit (a_block: NARRATE_BLOCK): LIST [SENTENCE]
```

Neither appears in a `require`. Making `split_at` reject a mid-sentence offset, or
`segment` reject a 60-word sentence, would make the author's cadence *illegal*
rather than *flagged* — and §8.5 argued the tool has no standing to decide either.

**Worth stating as a design rule:** a precondition encodes what the software cannot
do anything sensible with. A warning encodes what the software disagrees with.
Confusing the two produces tools that fight their users, and it is an easy mistake
in a language that makes preconditions so pleasant to write.

### 19.5 Loop assertions

★ **In the respelling search (§17.3), the loop invariant *is* the safety property.**
It says: at no point does this loop hold a candidate it has not proven.

```eiffel
search_respelling (a_word: STRING_32): detachable LEXICON_ENTRY
    require
        word_not_empty:     not a_word.is_empty
        not_already_proven: not lexicon.is_proven (a_word)
    local
        l_cands: ARRAYED_LIST [STRING_32]
    do
        l_cands := generate_candidates (a_word)
        from
            l_cands.start
        invariant
            no_unproven_promotion:
                Result = Void or else round_trip_returns (Result.alias, a_word)
            index_in_range:
                l_cands.index >= 1 and l_cands.index <= l_cands.count + 1
        until
            l_cands.after or Result /= Void
        loop
            if round_trip_returns (l_cands.item, a_word) then
                create Result.make_proven (a_word, l_cands.item, last_evidence)
            end
            l_cands.forth
        variant
            l_cands.count - l_cands.index + 1
        end
    ensure
        proven_or_nothing: Result = Void or else Result.is_proven
        evidence_attached: attached Result as r implies r.evidence /= Void
        nothing_installed: lexicon.proven_count = old lexicon.proven_count
    end
```

`nothing_installed` matters: the search *returns* a proven entry, it does not
install one. Promotion stays a separate, deliberate command.

**Assembly** carries a variant plus an invariant keeping the concat list in step
with what has been processed:

```eiffel
from i := 1
invariant
    list_tracks_progress: l_list.count = i - 1
    duration_monotonic:   accumulated_ms >= old accumulated_ms
until i > segments.count
loop
    ...
    i := i + 1
variant
    segments.count - i + 1
end
```

### 19.6 Check assertions

`check` is for intermediate truths that would otherwise fail far from their cause.

```eiffel
    -- after an atomic save (§6.2)
check tmp_removed: not file_system.exists (tmp_path) end

    -- after ffmpeg concat (§14.1)
check concat_exit_clean: ffmpeg.last_exit_code = 0 end

    -- ★ the truncated-WAV trap: a silent corruption that plays and may pass
check duration_plausible:
    (probe (a_out).duration_ms - expected_ms).abs <= Tolerance_ms
end

    -- before -c copy, the assumption the whole join rests on
check uniform_format:
    across renders as r all r.format ~ Reference_format end
end
```

★ The duration check catches §6.2's silent corruption structurally. A truncated
render plays, simply stops early, and could pass a word-level fidelity gate on the
words that survived. Measured duration against expected duration catches what the
gate cannot.

### 19.7 Contracts on the deferred engine

★ **This pays off most over time.** Contracts on a deferred feature bind every
backend that will ever exist — including ones written after this spec is forgotten.

```eiffel
deferred class TTS_ENGINE

feature -- Status
    is_available: BOOLEAN deferred end
    last_error: STRING_32

feature -- Synthesis
    synthesize (a_seg: NARRATE_SEGMENT; a_out: PATH): BOOLEAN
        require
            available:     is_available
            text_present:  not a_seg.text.is_empty
            seed_pinned:   a_seg.seed > 0
            output_absent: not file_system.exists (a_out)
        deferred
        ensure
            file_on_success:   Result implies file_system.exists (a_out)
            error_on_failure:  not Result implies not last_error.is_empty
            silent_on_success: Result implies last_error.is_empty
            format_uniform:    Result implies format_of (a_out) ~ Reference_format
            non_zero_audio:    Result implies probe (a_out).duration_ms > 0
        end

invariant
    error_implies_message: has_error implies not last_error.is_empty
```

A backend for a model that does not exist yet inherits all five postconditions.
`format_uniform` is what makes §14.1's lossless concat safe: the assumption is not
a comment for a future implementer to miss, it is an obligation they cannot
decline.

### 19.8 ⚠ A bug this pass found: the gate cannot be an assertion

The spec has said since draft 1 that publishing carries
`ensure fidelity >= gate_threshold`. **Writing the contract layer out revealed
that this is wrong**, and the reason is specific to how this ecosystem ships.

`ec.sh release` produces two binaries: a fat one with `-keep` (assertions live)
and a lean one without. **In the lean binary an `ensure` is gone.** The gate the
entire design exists to enforce would silently evaporate in the shipped
executable.

| | catches | must survive `release` |
|---|---|---|
| **Contract** | a *programmer* error — this feature was called wrongly | no |
| **Validation** | a *content* error — this essay is not ready | **yes** |

So the gate is a query the application always evaluates and acts on, and the
contract guards the call:

```eiffel
is_publishable: BOOLEAN
        -- ★ a real query, evaluated in every build
    do
        Result := (across blocks as b all b.is_approved end) and
                  fidelity >= gate_threshold
    end

publish (a_out: PATH)
    require
        ready: is_publishable       -- programmer error to call it otherwise
    ...
```

The `require` states that calling `publish` on an unready session is a defect in
the caller. The query is what the caller checks. Both are needed, and only one
survives finalisation without `-keep`.

⚠ The same reasoning applies to `require not is_stub` and
`require no_unfilled_respell_slots`. **Any contract in this spec that guards
against bad *content* rather than bad *calls* must be re-read as a validation and
given a companion query.**

---

## 19. Testing plan

The point of the suite is not coverage of features. It is **coverage of the
assertions in §19** — every contract exercised from both sides, and every design
claim written as a postcondition actually made to fail.

Ecosystem shape: `TEST_APP` runner, test classes inheriting `TEST_SET_BASE`, run
against the **fat** binary from `ec.sh test` so assertions are live.

### 20.1 Contract-violation tests — both sides of every clause

For each `require`, a test proving the guard fires:

```eiffel
test_split_rejects_offset_at_boundary
    do
        assert_violates_precondition ("offset_inside",
            agent session.split_at (block, 0))
        assert_violates_precondition ("offset_inside",
            agent session.split_at (block, block.text.count))
    end
```

For each `ensure`, a test proving the clause is satisfied by real work — and where
a clause encodes a design claim, **a test that would fail if the claim were false.**
`nothing_rendered` on `move_block_up` is only meaningful if something would have
caught a stray render.

### 20.2 ★ Cost-model tests

The design's economics are contracts, so they are testable — and these catch the
future regression that "works" but is slow:

| test | asserts |
|---|---|
| `test_move_costs_nothing` | `renders_performed` unchanged across a move |
| `test_reorder_ten_blocks_renders_zero` | still zero across ten moves |
| `test_split_costs_exactly_two` | `pending_renders` +2, not +3 |
| `test_kind_change_costs_nothing` | pacing is assembly-time, not render-time (§8.6) |
| `test_undo_costs_nothing` | the old hash's render is still cached (§8.2.1) |
| `test_lexicon_add_dirties_only_matching` | proving `Chemosh` does not dirty 200 blocks |

★ The last guards §6's decision to hash *applied* entries rather than a lexicon
version — precisely the mistake a well-meaning refactor would reintroduce.

### 20.3 Round-trip and property tests

- **Session file** — parse → write → parse yields an identical model. It is the
  only place hours of work live.
- **Split/merge** — `text_conserved` under randomised offsets; merge is the exact
  inverse of split at the same point.
- **Undo/redo** — after any operation sequence, `undo` × *n* then `redo` × *n*
  returns a model equal to the original. Grouped commands
  (`is_bound_to_next`) undo as one step.
- **Hash stability** — the same block, serialised and reloaded, hashes identically.
  Guards the §16.3 lexicon-ordering bug from returning.

### 20.4 Fault injection

⚠ §6.2's durability claims are worthless untested, and every one is testable:

| injected fault | expected |
|---|---|
| kill between `.tmp` write and rename | previous session intact, no partial file |
| kill mid-render | stray `.part` found and removed at startup; block dirty |
| truncate a cached WAV | `duration_plausible` fires at assembly |
| corrupt the session file | refuses to load rather than loading partially |
| `ffmpeg` absent from PATH | preflight fails clearly, nothing half-written |
| cache file deleted behind the app | block goes dirty, re-renders, no crash |

### 20.5 ★ Engine conformance suite

One test set **every** `TTS_ENGINE` backend must pass. Adding a backend means
running the suite, not reading the spec:

- all five §18.7 postconditions hold on success
- failure leaves `last_error` non-empty and writes no output file
- the same segment and seed rendered twice produces the same duration
  (⚠ within tolerance — determinism is best-effort, §8.1)
- output format matches `Reference_format` exactly, since `-c copy` depends on it

### 20.6 Gate tests with a fixed oracle

The gate's own correctness needs ground truth that does not move: a checked-in WAV
with a known transcript, so fidelity scoring is tested independently of any TTS
engine. Then §17.4's prosody measurements against clips with known timing — a
deliberately rushed reading, a clip with a planted two-second pause — asserting the
measurement finds what was planted.

### 20.7 Adversarial pass

Following the pattern already used in `simple_ocr_capture` (`hardening/`, the
X01–X10 series and its mutation work): assertions are not trusted until something
has tried to get past them. Contract clauses get mutated one at a time — invert a
comparison, drop a conjunct — and a mutation no test kills marks a clause the suite
is not really exercising.

### 20.8 ★ The test that runs in production

The round-trip gate is a test in the ordinary sense — synthesise, transcribe,
compare against expected — that happens to run on every essay rather than in CI.
And §17.6's lexicon regression suite is the same trick pointed at the environment:
every proven entry re-run when the model, voice, or engine changes.

**The suite and the product share a mechanism.** Worth saying plainly: the reason
this design can survive a field that turns over monthly is that its correctness
check does not care which model produced the audio.

---

## 20. Open questions

1. ~~MP3 encoding~~ — **resolved §14.1.** `ffmpeg` via `simple_process`.
2. ~~Do concat/crossfade go into `simple_audio`?~~ — **resolved §14.1: no.**
   `simple_audio` is untouched; its role is per-block playback for the ear gate.
3. ~~Sentence splitting~~ — **resolved: you split, the tool flags.** See §8.5:
   this is a *sentence* split (rewriting words), distinct from a *block* split
   (which the tool performs).
4. ~~Project directory~~ — **resolved §6.** A `projects_root` setting in
   `%APPDATA%\simple_narrate\settings.json` points at the session-folder tree;
   each essay is one session folder holding everything.
5. ~~Headings~~ — **resolved §8.6.** Own block kind, with lead and trail silence
   applied at assembly. Durations tuned by ear.
6. ~~Cache eviction~~ — **resolved: never.** Sessions and renders are kept
   indefinitely, and the final output lives in the session folder. This is also
   what makes undo free (§8.2.1).

### Still open

7. ~~Render cache as files or one blob?~~ — **resolved §6: a cloud of files**,
   one per segment, ffmpeg'd into one deliverable once every block is approved.
   Named `<block-id>.<hash>.wav`.
8. **Source re-import.** When the essay changes after import, how does the
   session take the update without discarding approvals? `simple_diff`
   (`diff_engine`, `diff_hunk`, `patch_applier`) is the mechanism; the *policy* —
   which blocks survive an ambiguous hunk — is still unspecified.
9. **Undo granularity.** `UNDO_CMD.is_bound_to_next` gives grouping — what gets
   grouped? Per keystroke is unusable; per operation may be too coarse for text
   editing inside a block.
10. **Undo history growth.** It persists in the session file indefinitely (§8.3).
    Cap it, or let it grow with the essay?
11. **Where does the global lexicon live?** §10 says global with per-project
    overrides; §6 puts it in `settings.json`. Confirm it belongs there rather
    than in its own file.
