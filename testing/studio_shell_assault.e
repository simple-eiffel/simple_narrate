note
	description: "[
		Phase S2, step 1 under assault: THE SHELL, proven with no desktop.

		SW_WINDOW allocates its offscreen frame and painter in `make' and
		creates nothing native until `run', so the whole Studio window is
		built, laid out, rendered and asserted here headless - the way
		simple_chat's pane is proven.

		THE GATE the spec names for this step (spec-studio-frame.md F7,
		step 1): the window opens, and Hebrew in a label reads
		right-to-left. The second half is read from the layout the
		breadcrumb itself builds through the window's shaping kit - the
		base direction is RTL and the FIRST source character paints in
		the RIGHT half of the width - and the rendered frame is written
		to evidence/ for a human to look at. That assertion is what
		simple_widgets 0.8.1 was built for.

		WHAT CANNOT BE PROVEN HERE: that the native window comes up on
		Larry's desktop. `narrate.exe` is that proof, by eye.
	]"
	author: "Larry Rix"

class
	STUDIO_SHELL_ASSAULT

inherit
	TEST_SET_BASE

feature -- The frame

	test_the_shell_opens_shaped_with_every_zone_empty
			-- Built and rendered offscreen: shaped text on, seven pads,
			-- three dock zones collapsed to nothing so the centre is
			-- the frame, Publish blocked and saying why, no essay.
		local
			s: STUDIO_SHELL
			r: TUPLE [rx, ry, rw, rh: REAL_64]
		do
			s := shell
			assert_true ("the window carries a shaping kit", attached s.window.shaping)
			assert_false ("no essay is open", s.has_essay)
			assert_integers_equal ("seven pads", 7, s.menu_bar.labels.count)
			assert_true ("File first", s.menu_bar.labels.first.has_substring ("File"))
			assert_true ("Help last", s.menu_bar.labels.last.has_substring ("Help"))
			assert_true ("no panel is docked yet", s.dock.panels.is_empty)

			s.window.request_render
			assert_real_greater_than ("the dock was laid out", s.dock.width, 100.0)
			assert_real_greater_than ("and stands tall", s.dock.height, 100.0)
			r := s.dock.zone_rect ({SW_DOCK_HOST}.Zone_west)
			assert_true ("the west zone collapsed to nothing", r.rw < 0.001)
			r := s.dock.zone_rect ({SW_DOCK_HOST}.Zone_east)
			assert_true ("the east zone collapsed to nothing", r.rw < 0.001)
			r := s.dock.zone_rect ({SW_DOCK_HOST}.Zone_south)
			assert_true ("the south zone collapsed to nothing", r.rh < 0.001)
			r := s.dock.center_rect
			assert_true ("so the centre is the whole dock", (r.rw - s.dock.width).abs < 0.001 and (r.rh - s.dock.height).abs < 0.001)

			assert_false ("Publish is blocked", s.publish_button.is_enabled)
			assert_true ("and says why on its face", s.publish_button.label.has_substring ("no essay"))
			assert_false ("the status bar speaks", s.status_bar.left_text.is_empty or s.status_bar.right_text.is_empty)
			assert_true ("the breadcrumb says no essay", s.title.has_substring ("No essay"))
			assert_true ("every toolbar tool is greyed in step 1",
				across s.toolbar.items as ic all ic.gap or not ic.enabled end)
		end

	test_a_hebrew_title_reads_right_to_left
			-- THE GATE. A Hebrew essay title in the breadcrumb: the
			-- label's own layout is RTL, its first letter paints
			-- rightmost, and the frame is on disk for a human.
		local
			s: STUDIO_SHELL
			geometry: SW_SHAPED_TEXT
			span: TUPLE [left, width: REAL_64]
			evidence: STRING_32
		do
			s := shell
			s.show_title (hebrew_title)
			assert_true ("the title took", s.title.same_string (hebrew_title))
			s.window.request_render
			assert_true ("the breadcrumb is on the shaped path", s.breadcrumb.takes_shaped_path (s.window.painter))
			if attached s.breadcrumb.shaped_layout (s.window.painter, 0.0) as l_layout then
				assert_integers_equal ("first-strong is Hebrew, so the title is RTL",
					{SHAPING_CONSTANTS}.Direction_rtl, l_layout.base_direction)
				assert_true ("its run is RTL", l_layout.lines.first.runs.first.is_rtl)
				create geometry.make
				span := geometry.character_span (l_layout, 1)
				assert_real_greater_than ("the first letter paints in the RIGHT half",
					span.left, l_layout.total_width / 2.0)
				assert_real_greater_than ("one glyph wide", span.width, 1.0)
				assert_real_greater_than ("and the label is as wide as the layout",
					s.breadcrumb.preferred_width (s.window.painter), l_layout.total_width - 0.001)
			else
				assert_true ("the breadcrumb built a shaped layout", False)
			end
			evidence := evidence_path ("studio-shell-hebrew.png")
			if not evidence.is_empty then
				assert_true ("the frame is on disk", s.window.write_frame (evidence))
				print ("    written ")
				print (evidence)
				print ("%N")
			end
		end

feature -- Honest chrome

	test_the_menus_offer_only_what_exists
			-- Every menu is built fresh: in step 1 only Exit and About
			-- are enabled, because only they do anything.
		local
			s: STUDIO_SHELL
			m: SW_MENU
		do
			s := shell
			m := s.file_menu
			assert_integers_equal ("File: open, a separator, exit", 3, m.items.count)
			assert_false ("Open essay is greyed until step 2", m.items.first.enabled)
			assert_true ("the middle is the separator", m.items.i_th (2).separator)
			assert_true ("Exit is offered", m.items.last.enabled)
			assert_true ("and does something", attached m.items.last.action)
			m := s.help_menu
			assert_true ("About is offered", m.items.last.enabled and attached m.items.last.action)
			assert_true ("Edit offers nothing yet", across s.edit_menu.items as ic all not ic.enabled end)
			assert_true ("Block offers nothing yet", across s.block_menu.items as ic all not ic.enabled end)
			assert_true ("Voice offers nothing yet", across s.voice_menu.items as ic all not ic.enabled end)
			assert_true ("Render offers nothing yet", across s.render_menu.items as ic all not ic.enabled end)
			assert_true ("Export offers nothing yet", across s.export_menu.items as ic all not ic.enabled end)
			assert_integers_equal ("Block: new take, split, lock", 3, s.block_menu.items.count)
			assert_integers_equal ("Export: publish, EDL", 2, s.export_menu.items.count)
		end

feature -- The tokens

	test_the_theme_faces_are_loaded
			-- The three vendored faces registered for this process, so
			-- Archivo, Literata and IBM Plex Mono are real and not
			-- Segoe's stand-ins.
		local
			s: STUDIO_SHELL
		do
			s := shell
			assert_integers_equal ("Archivo, Literata and IBM Plex Mono", 3, s.fonts_registered)
		end

	test_the_frame_wears_the_style_spec_tokens
			-- SW_THEME.make_light IS style_spec.md section 2, value for
			-- value - checked here so a retune in the toolkit cannot
			-- silently redress the Studio. And the split-preview pair
			-- differs in LUMINANCE, the law that section carries.
		local
			s: STUDIO_SHELL
			t: SW_THEME
		do
			s := shell
			t := s.theme
			assert_true ("app_background", t.background = 0xE9ECF1)
			assert_true ("surface", t.surface = 0xFFFFFF)
			assert_true ("surface_variant", t.surface_variant = 0xF5F7FA)
			assert_true ("outline", t.outline = 0xD3DAE3)
			assert_true ("on_surface", t.ink = 0x1A2029)
			assert_true ("on_surface_variant", t.ink_muted = 0x5A6573)
			assert_true ("state_rendered is the accent", t.accent = 0x1F5FA8)
			assert_true ("state_approved", t.success = 0x1D6B52)
			assert_true ("state_dirty", t.warning = 0x8A5A0B)
			assert_true ("state_failed", t.danger = 0xAF3A22)
			assert_true ("wash_rendered", t.wash_accent = 0xC7DAF1)
			assert_true ("wash_dirty", t.wash_warning = 0xFAF1DD)
			assert_true ("Archivo for the tool's voice", t.family_ui.same_string_general ("Archivo"))
			assert_true ("Literata for the author's prose", t.family_body.same_string_general ("Literata"))
			assert_true ("IBM Plex Mono for machine values", t.family_mono.same_string_general ("IBM Plex Mono"))
			assert_real_greater_than ("the split-preview washes differ in luminance, not merely hue",
				t.contrast_ratio (t.wash_accent, t.wash_warning), 1.2)
			assert_true ("readable text on the ground", t.contrast_ratio (t.ink, t.surface) >= 4.5)
			assert_true ("text is half again the library size", (t.text_scale - 1.5).abs < 0.001)
		end

feature {NONE} -- Fixtures

	shell: STUDIO_SHELL
			-- A fresh shell, never shown.
		do
			create Result.make (0, 0, 1280, 800)
		ensure
			never_shown: Result.window.hwnd = default_pointer
		end

	hebrew_title: STRING_32
			-- "The Leash" in Hebrew - he-resh-tsadi-vav-ayin-he - as
			-- code points, so this file's encoding is never on trial.
		do
			Result := text_of (<<0x05D4, 0x05E8, 0x05E6, 0x05D5, 0x05E2, 0x05D4>>)
		ensure
			six_code_points: Result.count = 6
		end

	text_of (a_codes: ARRAY [INTEGER]): STRING_32
			-- `a_codes' as one STRING_32 code point per entry.
		local
			i: INTEGER
		do
			create Result.make (a_codes.count)
			from i := a_codes.lower until i > a_codes.upper loop
				Result.append_code (a_codes [i].to_natural_32)
				i := i + 1
			end
		ensure
			one_per_code_point: Result.count = a_codes.count
		end

feature {NONE} -- Locating things on disk

	evidence_path (a_name: STRING): STRING_32
			-- `<repo>/evidence/<a_name>', where `<repo>' is the first
			-- ancestor of the working directory or of the exe's folder
			-- that holds `simple_narrate.ecf'; empty when the repository
			-- is not underfoot.
		require
			name_not_empty: not a_name.is_empty
		local
			env: EXECUTION_ENVIRONMENT
			starts: ARRAYED_LIST [PATH]
			base, marker, dir: PATH
			d: DIRECTORY
			i, step: INTEGER
			found: BOOLEAN
		do
			create Result.make_empty
			create env
			create starts.make (2)
			starts.extend (env.current_working_path)
			starts.extend ((create {PATH}.make_from_string (env.arguments.command_name)).parent)
			from i := 1 until i > starts.count or found loop
				base := starts [i]
				from step := 0 until step > 6 or found loop
					marker := base.extended ("simple_narrate.ecf")
					if file_exists (marker.name) then
						dir := base.extended ("evidence")
						if not directory_exists (dir.name) then
							create d.make_with_path (dir)
							d.recursive_create_dir
						end
						if directory_exists (dir.name) then
							Result := dir.extended (a_name).name.to_string_32
						end
						found := True
					else
						base := base.parent
					end
					step := step + 1
				end
				i := i + 1
			end
		end

	directory_exists (a_path: READABLE_STRING_32): BOOLEAN
		local
			d: DIRECTORY
		do
			create d.make_with_name (a_path)
			Result := d.exists
		end

	file_exists (a_path: READABLE_STRING_32): BOOLEAN
		local
			f: RAW_FILE
		do
			create f.make_with_name (a_path)
			Result := f.exists
		end

end
