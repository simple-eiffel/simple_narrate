# simple_narrate — THE STUDIO FRAME

**A frame-out of the Studio window, derived from ElevenLabs Studio.** Companion
to [`spec-studio.md`](spec-studio.md) §S7, which said the ElevenLabs layout is
*"a starting point, not a specification."* This document is that starting point
drawn to the widget.

Sources, read 2026-09-05:

- Larry's screenshot of the classic Studio paragraph editor (project *Beacon*,
  chapter *Introduction*, 10:28 of narration, Eleven v3, voice *Adam*)
- ElevenLabs product guide: https://elevenlabs.io/docs/product-guides/products/studio
- ElevenLabs help centre: https://elevenlabs.io/docs/help-center/product/studio/studio/what-is-studio
- ElevenCreative Studio 3.0 overview: https://elevenlabs.io/docs/eleven-creative/products/studio

Status: **specification.** No code. Nothing here has compiled.

**Where it lives: `simple_narrate`.** The Studio is the `narrate` application
target in `simple_narrate.ecf`. `simple_voice` (Piper), `simple_comfyui`
(plates), `simple_speech` (gate), `simple_widgets` + `simple_shaping` +
`simple_cairo` (the face) are libraries beneath it. Nothing Studio-shaped goes
into a library.

---

## F0. What the screenshot shows — the anatomy of the reference

Read left to right, top to bottom. Every element is named so the verdict table
can refer to it.

| # | region | contents |
|---|---|---|
| 1 | **Top bar** | menu, **undo / redo**, breadcrumb *Beacon / Introduction ▾* (project / chapter), *300,000 credits remaining*, notes, sync, **Share**, **Export** |
| 2 | **Left rail** (icon tabs) | **Edit**, **Chapters**, **Voices**, SFX, Music, **Files** |
| 3 | **Contextual panel** *Edit Speech* | **Playback**: Volume 100 %, Fade In 0 s, Fade Out 0 s · **Type**: Text · **Model**: Eleven v3 · **Voice**: *Adam – Dominant, Firm* (Default) + **Override settings** toggle · **Generation History**: four timestamped takes, one ✓ current · **AI Tools**: Enhance text, Remove background audio, Use voice changer, **Direct speech with your voice** |
| 4 | **Paragraph column** | one row per paragraph: a **voice orb** at the left, a **vertical status bar** (light = unconverted, dark = converted), the prose. The heading is its own paragraph. |
| 5 | **Paragraph toolbar** (floats above the column) | **Regenerate**, insert break, **lock**, versions |
| 6 | **Transport** (bottom) | layout toggle, play-mode, **1.0×** speed, ⏮ **▶** ⏭, **0:00 / 10:28**, zoom, expand; a progress strip beneath |

Two things the picture says that the docs do not. First, the whole chapter is
one flat column of paragraphs with the heading inline, not a tree. Second,
selection is paragraph-granular: the highlighted region in the screenshot runs
paragraph to paragraph, and the orb is the one per-paragraph control.

---

## F1. Feature verdicts — keep, adapt, drop

*Keep* means the concept survives as is. *Adapt* means the concept survives
under a different mechanism already in the spec. *Drop* means it is outside
`spec-studio.md` §S10's fence.

### F1.1 The paragraph column

| ElevenLabs | verdict | simple_narrate |
|---|---|---|
| paragraph | **keep** | `NARRATE_BLOCK` (`spec.md` §8). Same unit of everything. |
| status bar, two states (unconverted / converted) | **adapt** | the **severity stripe**, six states: `empty · rendering · current · stale · invalid · failed` (§S7.3, `style_spec.md` §2 colours). Two states cannot express *stale*, and stale is the state this program exists to show. |
| voice orb per paragraph | **keep** | the **palette dot** (§S3.3): colour = `VOICE_SLOT.colour`. Click → reassign. Multi-select + assign once. |
| heading as a paragraph | **keep** | `kind = heading` (`spec.md` §8.6). Same column, own pacing. |
| multiple voices *inside* one paragraph, colour-highlighted | **drop** | one voice per block (§S2). Split the block instead — that is what split-at-caret is for. |
| word-level regenerate | **drop** | their own guidance is *"regenerate a complete phrase or sentence"*; the block is that. Emphasis is the segment splice (`spec.md` §9). |
| 400 paragraphs / chapter, 5,000 chars / paragraph | **drop** | no hard limits; the 35-word sentence *flag* (`spec.md` §8.5) instead. |

### F1.2 The paragraph toolbar

| ElevenLabs | verdict | simple_narrate |
|---|---|---|
| **Regenerate** (two free, then charged) | **adapt** | **New take**: same text, `seed + 1` (`spec.md` §8.1, §18.7). Unlimited; the cost shown is wall-clock, from `last_duration_ms`. |
| insert break (≤ 3 s) | **adapt** | the marks `\|`, `\|\|`, `\|\|\|`, `[[1.4]]` (§S6.1). Typed, visible, any length. |
| **Lock paragraph** | **keep** | `is_locked` on the block. Locked = no edit, no re-render, no voice change until unlocked. Requires `is_approved`. `spec.md` §16.4 already wanted this: a lock *enforces* what approval *records*. |
| versions | **adapt** | takes (below). |

### F1.3 The contextual panel

| ElevenLabs | verdict | simple_narrate |
|---|---|---|
| Playback: Volume | **drop** for v1 | loudness is normalised per block at assembly (§S3.4). A per-block trim can come later as an `ENGINE_PARAMS` field. |
| Playback: Fade In / Out | **drop** | pacing is kind-based silence at assembly (`spec.md` §8.6), never baked into a render. |
| Type: Text | **adapt** | block **kind**: `prose · heading · separator`. |
| Model | **adapt** | lives on the **slot**, not the block: `VOICE_SLOT.engine_ref` (§S3.1). Changing a model never touches a block. |
| Voice + **Override settings** | **keep, and it maps exactly** | slot picker + a switch that means *this block carries its own `ENGINE_PARAMS`* (`spec.md` §8.1). Off = inherit the slot's defaults. On = the block's params are its own and survive re-render. |
| voice settings: stability, similarity, speed, style | **adapt** | engine-specific `ENGINE_PARAMS`: Piper `length_scale · noise_scale · noise_w`; Chatterbox `exaggeration`. The panel is generated from the engine's declared parameters, not hard-coded. |
| **Generation History**: play, restore, delete, one ✓ | **keep** | **Takes** (§S7.4): N renders per block, one current, each with fidelity and duration. Play, make current, delete. |
| AI: Enhance text | **drop** | the tool flags (35 words, mid-sentence split) and never rewrites (`spec.md` §18.4). |
| AI: Remove background audio | **drop** | not a mastering suite. |
| AI: Voice changer | **drop** | not in scope; `recorded` slots cover "my voice". |
| AI: **Direct speech with your voice** (Actor Mode) | ★ **adapt — this is §S5** | Actor Mode replicates your delivery into the model's audio. Ours extracts your delivery as **marks** that survive edits and transfer to any voice (§S5.3). Same button, better output. Also the `recorded` slot (§S3.2) for the cases where you simply want your own voice. |

### F1.4 Rails, chapters, files

| ElevenLabs | verdict | simple_narrate |
|---|---|---|
| Edit tab | **keep** | the inspector (F3, east). |
| **Chapters** tab: add, rename, reorder, auto-detect on import | **adapt** | a session is one essay; **headings are the chapters**. The **map rail** (`style_spec.md` §3) lists headings and paints every block's state as a cell. Click a heading to jump. |
| **Voices** tab | **adapt** | the **palette** (§S3): ordered slots, add / rename / recolour / retarget. |
| SFX, Music | **drop** | §S10. Not a DAW. |
| **Files** | **adapt** | **plates** (§S4) and **recorded WAVs** (§S3.2). Import, bind, never generate here — generation is the `PLATE_ENGINE` service (`spec-plates.md` §P0). |
| import EPUB / PDF / DOCX / TXT / HTML / URL | **adapt** | Markdown only (`spec.md` §7 import). |
| pronunciation dictionary (alias + phoneme) | ★ **adapt — ours is stronger** | the **lexicon** (`spec.md` §10, §17.3): ordered, first match wins, and **candidate vs proven** with round-trip evidence. A lexicon tab in the west dock. |

### F1.5 Transport and top bar

| ElevenLabs | verdict | simple_narrate |
|---|---|---|
| ▶ with three modes: *until end (generate ahead)* · *until end (one at a time)* · *selection* | **keep** | play **Block · From here · All**, and playing a `stale` block renders it first through the detached worker (`spec.md` §15). |
| ⏮ ⏭ | **keep** | previous / next block. |
| **0:00 / 10:28** | **keep** | block clock and essay clock, from measured take durations. |
| speed 0.8×–2.0× | **drop** for v1 | `simple_audio` playback rate is unverified. |
| **undo / redo** | **keep** | session history (`spec.md` §8.3) for operations; `SW_TEXT_BOX`'s own stack for keystrokes (`verification-2026-09-05.md` §3.3). |
| credits remaining | **adapt** | **pending renders × last render time**, in the status bar. The honest cost. |
| **Export**: MP3 / WAV, per chapter or whole, metadata, *volume normalization* | **adapt** | **Publish** → `essay.mp3` or `essay.HOLD.mp3` (`spec.md` §11) plus the **EDL** for the video assembler (§S9 Phase S4). Normalisation is not optional (§S3.4). |
| **Share**, comments, read-only links | **drop** | nothing leaves the machine. |
| project / chapter breadcrumb | **adapt** | *project / essay* from the session folder path (`spec.md` §6). |

### F1.6 Studio 3.0 timeline, tracks, captions

| ElevenLabs 3.0 | verdict | simple_narrate |
|---|---|---|
| timeline with narration / music / SFX / video tracks | **drop** | §S10, explicitly. |
| per-sentence timing adjustment | **adapt** | marks at sentence boundaries (§S6), and sentence-split synthesis gives the timings for free (`spec-piper.md` V7). |
| captions, templates | **adapt** | the EDL carries caption cues (§S9 Phase S4); rendering them is the video assembler's job. |
| video track | **adapt** | plate spans (§S4) are the block-granular equivalent. |
| waveform on the track | ★ **keep** | a waveform per block in the inspector, drawn from the take's `AUDIO_BUFFER`. `style_spec.md` §3 argued this: a 22-second unbroken run is a solid bar of ink, and the boundary silence the gate measures is a gap you can see. |

---

## F2. The frame

```
┌ menu bar ───────────────────────────────────────────────────────────────────┐
│ File  Edit  Block  Voice  Render  Export  Help                              │
├ toolbar ────────────────────────────────────────────────────────────────────┤
│ ↶ ↷ │ The Leash / 01 · The Day Yahweh Looked Defeated │ Render dirty  Gate │
│                                                   [ Publish · 12 unapproved ]│
├──────────┬──────────────────────────────────────────────────┬───────────────┤
│ WEST     │ CENTRE — the block thread                        │ EAST          │
│ ▸Palette │ ┃●│ Introduction: The Question Behind…      ✓0.98 │ BLOCK 8       │
│  ● Narr. │ ┃●│ In one-twelve CE a Roman governor sat…       │ ─ Voice ────  │
│  ● Objct │ ┃●│ …the instructions he received did not…       │  ● Narrator ▾ │
│  ● Larry │ ┃●│ Modern American evangelicalism has been…     │  [ ] override │
│  [rec]   │ ───────── plate: ep03_library ───────────────    │  length 1.00  │
│ ▸Map     │ ┃●│ Why aren't we growing ‖ the way…  ▲ tint     │  seed 4171    │
│  ▪▪▪▪▪▪▪ │ ┃●│ The numbers behind the question are real…    │ ─ State ────  │
│  ▪▪▪▪▪▪▪ │ ┃●│ …no reversal of the downward trajectory.     │  STALE · 0.94 │
│ ▸Lexicon │                                                  │ ─ Takes ────  │
│  qodesh✓ │                                                  │  ● 14:58 ✓    │
│  Chemosh?│                                                  │  ○ 14:57      │
│          │                                                  │ ─ Waveform ─  │
│          │                                                  │  ▁▃▆▇▅▂ ▁▆▇▃  │
│          │                                                  │ ─ Plate ────  │
│          │                                                  │  [thumb / —]  │
├──────────┴──────────────────────────────────────────────────┴───────────────┤
│ ⏮  ▶  ⏭   0:07 / 10:28   [Block|From here|All]   ▓▓▓▓░░ rendering 3 of 12  │
│ status: 3 dirty · 2 pending renders ≈ 0:41 · gate 0.95 · engine piper/ryan  │
└─────────────────────────────────────────────────────────────────────────────┘
```

Legend for the thread row: `┃` the severity stripe (4 px, state colour), `●`
the palette dot, `✓0.98` the fidelity chip in mono, `‖` the caret with the
split-preview tint above and below (`spec.md` §8.4), the ruled line a plate
binding between blocks (§S7.2).

What moved from the reference, and why:

- **The palette is a dock panel, not a tab behind an icon.** Assigning voices
  to panel material is a drag-and-glance job; hiding the palette behind a tab
  costs a click per block.
- **The inspector is on the east, the reference's is on the west.** The eyes
  read left to right: structure (map), then prose (thread), then detail
  (inspector). The reference puts detail first because its paragraph column is
  the only thing it has on the left.
- **The transport gains a play-mode segmented control and a render progress
  bar**, because rendering is the long operation here and the reference hides
  its equivalent behind the play button's menu.

---

## F3. Widget map — every region names a real class

All classes exist in `simple_widgets/src` as of 0.7.2 (101 `sw_*` classes,
listed 2026-09-05) unless marked **gap**.

| region | class | notes |
|---|---|---|
| shell | `SW_WINDOW` + `enable_shaped_text` | one `SW_SHAPING` kit for the window's life (`sw_shaping.e`). Hebrew and Greek in prose come through it. |
| menu bar | `SW_MENU_BAR` | labels draw through the shaping kit since 0.7.2. |
| toolbar | `SW_TOOLBAR` | undo / redo, render dirty, run gate. **Publish** is a `SW_BUTTON` whose label carries the blocker text when disabled (`spec_windows.json` design principle 3). |
| breadcrumb | `SW_LABEL` | project / essay. |
| docking | `SW_DOCK_HOST` | west, east, south zones around the thread; an empty zone collapses. |
| **west: palette** | `SW_LIST` | one row per `VOICE_SLOT`: colour dot + name + kind `SW_CHIP` (`synthetic · cloned · recorded`). Right-click `SW_MENU`: rename, recolour, retarget, set default. |
| west: map rail | `SW_CANVAS` | one cell per block in its state colour, headings as labels, click to scroll the thread. `style_spec.md` §3 Tier 1. |
| west: lexicon | `SW_LIST` | word · alias · `SW_BADGE` candidate / proven. |
| west tabs | `SW_TABS` or three `SW_ACCORDION` sections | accordion keeps all three visible. |
| **centre: block thread** | ★ `SW_PARAGRAPH_LIST` (0.8.0) | variable-height shaped paragraphs measured through the kit, per-item revision cache, host-drawn gutter and bands, selection set with anchor, one paragraph edited in place. Built for this frame; see F6. |
| centre: editing | `SW_PARAGRAPH_LIST.begin_edit` seats a shaped `SW_TEXT_BOX` | the box edits shaped text since 0.8.0: caret and hit-test by cluster, Hebrew caret walks leftward. The §S7.1 fallback is retired. |
| centre: split preview | painter washes in the row renderer | `wash_rendered` above the caret, `wash_dirty` below; the pair's luminance ratio is a class invariant (`style_spec.md` §4). |
| centre: plate rule | `SW_SEPARATOR`, labeled variant | *"--- plate: ep03_library ---"* between rows. Already ships. |
| centre: stripe, dot, chips | draw calls in the row renderer | not widgets. 200 blocks as widget trees would be thousands of live handles. |
| **east: inspector** | `SW_ACCORDION` | sections below. Rebuilt on selection change from the block's state, never edited in place. |
| east: voice | `SW_SELECT` (slot) + `SW_SWITCH` (override) + per-param `SW_SLIDER` / `SW_NUMBER_BOX` | sliders generated from the engine's declared `ENGINE_PARAMS`. Seed is a `SW_NUMBER_BOX` in mono. |
| east: state | `SW_BADGE` (state, semantic kind) + `SW_STATISTIC` (fidelity) | one colour, one meaning. |
| east: takes | `SW_TIMELINE` | *"a dot per entry wearing its semantic kind, the time in mono, the title in ink"*. Exactly the Generation History list. Context menu: play, make current, delete. |
| east: waveform | `SW_WAVEFORM` (0.8.0) | `set_samples (frames, rate, agent buffer.sample_at (?, 0))`; markers for sentence boundaries; `on_seek` drives the player. |
| east: plate | `SW_IMAGE` or `SW_EMPTY_STATE` | thumbnail when the file exists; *"no plate bound"* when not. **Never a placeholder image** (`spec-plates.md` §P7). |
| **south: transport** | `SW_MEDIA_TRANSPORT` | codec-agnostic: the host subscribes `on_play / on_pause / on_seek` and drives `simple_audio`'s player. Honest `m:ss` clocks. |
| south: play mode | `SW_SEGMENTED` | Block · From here · All. |
| south: render progress | `SW_PROGRESS` | determinate while the worker runs; the detached-worker + polling pattern from `simple_ocr_capture`. |
| south: status | `SW_STATUS_BAR` | dirty count, pending renders and estimate, gate threshold, engine / voice. |
| dialogs | `SW_DIALOG` | mid-sentence split warning with *snap to boundary* (`spec.md` §8.4), unlock confirmation. |
| file pickers | `SW_FILE_DIALOG` | import essay, bind plate, import recorded WAV, publish. |
| voice reassign popup | `SW_MENU` from the dot | one item per slot with its colour. |
| capture (S5) | `SW_DICTATION` as the pattern | it already rides `simple_audio`'s recorder; S5 replaces the transcribe step with align-and-diff. |

Theme: the `style_spec.md` §2 tokens over `SW_THEME`. Fonts Archivo, Literata,
IBM Plex Mono are vendored in `fonts/` with the fallbacks `Segoe UI`,
`Georgia`, `Consolas`; `SW_SHAPING.set_theme_faces` prepends the theme face for
Latin only and leaves Hebrew and Greek to the library.

---

## F4. Interaction laws

Stated once, because each one is a contract or a validation somewhere else.

1. **The block is the unit** of selection, playback, regeneration, voice
   assignment, lock, and approval. Nothing operates on a range inside a block
   except the caret split.
2. **State is displayed, never inferred.** Every row shows exactly one of the
   six states; `stale` is amber and unmissable (§S7.3).
3. **Editing a rendered block makes it stale** through the definitional
   invariant, not through a mutator remembering to (`spec.md` §18.1). Editing a
   `recorded` block makes it `invalid` (§S3.2).
4. **A locked block refuses** edit, re-render and reassignment. Unlock is a
   deliberate command with a dialog.
5. **Regenerate never destroys** the previous take until you delete it (§S7.4).
6. **Play renders on demand** through the worker; the event loop never blocks.
7. **Publish always names its blocker** (`is_publishable` is a query, not a
   contract, `spec.md` §18.8).
8. **Warnings never block**: the 35-word sentence and the mid-sentence split
   are queries, and the dialog offers, never forces (`spec.md` §18.4).
9. **Multi-select then assign** is one gesture for a panel of six blocks
   (§S3.3).
10. **An empty plate slot is shown as empty.** Never substituted (§P7).

---

## F5. Deliberately not copied

Credits, Share, comments, cloud sync, SFX, Music, video track, timeline,
captions rendering, voice changer, background-audio removal, text enhancement,
word-level regeneration, in-paragraph multi-voice, playback speed (v1), per-block
fade. Each is either outside §S10's fence or replaced by something the spec
already does better.

---

## F6. Gaps this frame found in the toolkit — CLOSED 2026-09-05

Larry's rule on reading the gaps: *"If you need to build new widget-tools,
then design and build them. Let's not fudge any of this."* All three were
built in `simple_widgets` 0.8.0 (branch `feature/studio-widgets`), each with
contracts and a headless assault, suite 313/313, dependents rebuilt and run.

| gap | resolution | where |
|---|---|---|
| variable-height virtualised list | **`SW_PARAGRAPH_LIST`** — measured paragraphs, per-item revision cache, visible band painted, host-drawn gutter and bands, selection set with anchor, edit in place through a seated `SW_TEXT_BOX` | `simple_widgets/src/sw_paragraph_list.e`, 14 tests |
| waveform widget | **`SW_WAVEFORM`** — 4,096-column summary read once through a sampler agent (`agent buffer.sample_at (?, 0)`), playhead, markers, seek | `simple_widgets/src/sw_waveform.e`, 11 tests |
| shaped `SW_TEXT_BOX` | **shipped** — the box lays out through the kit, caret and hit-test by cluster in both directions, bidi tie resolved to the LTR boundary; `SW_CLUSTER_MATH` written once for the thread, the chrome cache and the box | `simple_widgets/src/sw_text_box.e`, `sw_cluster_math.e`, 10 tests |
| playback rate | still unverified in `simple_audio` | not v1 |

Consequence for F3: the centre pane is `SW_PARAGRAPH_LIST` directly, not a
derivation from `SW_CHAT_THREAD`; the plain-LTR editing fallback is no longer
needed, since the seated editor is the shaped text box.

## F7. Build order for Phase S2

Each step leaves a running window.

1. **Shell**: `SW_WINDOW` with shaped text, menu bar, toolbar, `SW_DOCK_HOST`
   with three empty zones, `SW_STATUS_BAR`. Tokens applied. *Gate: the window
   opens, Hebrew in a label reads right-to-left.*
2. **Block thread, read-only**: the six states drawn from a loaded session
   file; stripe, dot, chips; plate rules. *Gate: 200 blocks scroll.*
3. **Inspector**: state, voice, takes, plate sections bound to the selected
   block.
4. **Palette**: slots, reassign from the dot, multi-select assign.
5. **Transport**: play a take through `simple_audio`; block, from-here, all;
   render-on-demand through the worker with progress.
6. **Editing**: `SW_TEXT_BOX` in the focused row, stale on edit, undo at both
   levels.
7. **Split**: caret tint, snap-to-boundary dialog, `text_conserved`.
8. **Lock, approve, publish**: the blocker label, `essay.mp3` vs `HOLD`.
9. **Waveform** in the inspector.
10. **EDL export** (Phase S4 can start here).

Prosody capture (S3) hangs off step 5's transport and the `SW_DICTATION`
pattern, and stays cuttable.
