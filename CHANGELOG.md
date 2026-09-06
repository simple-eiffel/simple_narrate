# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added (Phase S2, step 1 — THE STUDIO SHELL, 2026-09-06)

- **`STUDIO_SHELL`** (`studio/`): one `SW_WINDOW` with shaped text on, the
  seven-pad menu bar (File / Edit / Block / Voice / Render / Export / Help,
  every menu built fresh on open so an item is enabled exactly when its command
  exists — in step 1, Exit and About), a toolbar (undo, redo, render dirty,
  gate; all greyed), the breadcrumb strip with a Publish button that carries its
  blocker as its label, an `SW_DOCK_HOST` whose three zones stand empty around
  an `SW_EMPTY_STATE` centre, and the status bar. The theme is
  `SW_THEME.make_light` untouched — it is `specs/gui/style_spec.md` §2 value for
  value — with Archivo, Literata and IBM Plex Mono registered from `fonts/`.
- **`STUDIO_APP`**: the `narrate` executable.
- **`STUDIO_SHELL_ASSAULT`**, 5 tests, headless: the shell opens shaped with
  every zone collapsed and the centre the whole dock; a Hebrew title in the
  breadcrumb is RTL with its first letter painting in the right half (the F7
  step-1 gate), frame written to `evidence/studio-shell-hebrew.png`; the menus
  offer only what exists; the three faces load; the frame wears the style-spec
  tokens and the split-preview washes differ in luminance.
- `simple_narrate.ecf` restructured: `simple_narrate` (library: `studio/` over
  simple_widgets + simple_cairo + simple_shaping + simple_shell), `narrate`
  (the Studio), `simple_narrate_tests`, and `narrate_editor` — the August 2026
  pure-Win32 block editor in `narrate_gui/`, kept buildable on its own target
  so its Win32 externals and simple_shell's never share a universe.
- Needs `simple_widgets` 0.8.1 (`SW_LABEL` on the shaped path).

### Earlier

- 2026-08-21: `narrate_gui/` — the block editor (caret, selection, split-tint),
  pure Win32 + simple_cairo; its text engine harvested into simple_widgets as
  `SW_TEXT_BOX`.
- 2026-09-05/06: the Studio design — `HANDOFF-STUDIO.md` and seven specs.
