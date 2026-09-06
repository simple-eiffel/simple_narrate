note
	description: "[
		The Studio window - Phase S2, step 1 of the F7 build order
		(specs/spec-studio-frame.md): THE SHELL, and nothing behind it
		yet.

		One SW_WINDOW with shaped text on, the seven-pad menu bar, a
		toolbar, the breadcrumb strip, an SW_DOCK_HOST whose three zones
		stand EMPTY around an empty-state centre, and the status bar.
		Every later step seats something into this frame: the block
		thread into the centre (step 2), the inspector into the east
		(step 3), the palette into the west (step 4), the transport into
		the south (step 5). Nothing here knows a block.

		THE GATE for this step is the one the spec names: the window
		opens, and Hebrew in a label reads right-to-left. The breadcrumb
		is that label - an essay's title is the author's, in whatever
		script the author writes - and `show_title' is what the assault
		drives. That gate is why simple_widgets 0.8.1 exists: until it,
		SW_LABEL painted on cairo's toy path and a Hebrew title read
		backwards two inches under a menu bar that shaped its own.

		HONEST CHROME. A menu item whose command does not exist yet is
		GREYED, not wired to nothing: the menus are built fresh on every
		open (SW_MENU_BAR takes builder agents), so an item is enabled
		exactly when the thing it does is possible right now. The
		Publish button carries its blocker as its label while disabled
		(spec_windows.json principle 3): "Publish - no essay open".

		THE THEME is SW_THEME.make_light untouched: it IS the token set
		style_spec.md section 2 specifies, value for value - Archivo,
		Literata and IBM Plex Mono included - which `register_fonts'
		loads from the fonts folder so the faces are real and not
		Segoe's stand-ins.

		HEADLESS BY CONSTRUCTION. SW_WINDOW creates nothing native until
		`run', so this whole shell is built, measured, rendered to its
		offscreen frame and asserted with no desktop - the way
		simple_chat's pane is.
	]"
	author: "Larry Rix"

class
	STUDIO_SHELL

create
	make

feature {NONE} -- Initialization

	make (a_x, a_y, a_width, a_height: INTEGER)
			-- The shell at `a_x', `a_y', `a_width' x `a_height', shaped
			-- text on, every dock zone empty, no essay open.
		require
			sane_size: a_width > 0 and a_height > 0
		local
			l_root: SW_COLUMN
			l_bar: SW_MENU_BAR
			l_toolbar: SW_TOOLBAR
			l_strip: SW_ROW
			l_dock: SW_DOCK_HOST
			l_status: SW_STATUS_BAR
			l_empty: SW_EMPTY_STATE
		do
			create theme.make_light
			theme.set_text_scale (Text_scale)
			create window.make (Window_title, a_x, a_y, a_width, a_height, theme)
			register_fonts
			window.enable_shaped_text

			create breadcrumb.make_ui (Text_no_essay)
			breadcrumb.set_grow (1.0)
			create publish_button.make_primary (Text_publish_blocked, Void)
			publish_button.set_enabled (False)

			create l_toolbar.make
			l_toolbar.add_tool (Text_undo, Text_undo_hint, False, Void)
			l_toolbar.add_tool (Text_redo, Text_redo_hint, False, Void)
			l_toolbar.add_gap
			l_toolbar.add_tool (Text_render_dirty, Text_render_dirty_hint, False, Void)
			l_toolbar.add_tool (Text_gate, Text_gate_hint, False, Void)
			toolbar := l_toolbar

			create l_strip.make
			l_strip.put (breadcrumb)
			l_strip.put (publish_button)

			create l_empty.make (Text_empty_title, Text_empty_message)
			create l_dock.make (l_empty)
			dock := l_dock

			create l_status.make
			l_status.set_left (Text_status_idle)
			l_status.set_right (Text_engine_none)
			status_bar := l_status

			create l_bar.make
			menu_bar := l_bar

			create l_root.make
			l_root.put (l_bar)
			l_root.put (l_toolbar)
			l_root.put (l_strip)
			l_root.put (l_dock.growing)
			l_root.put (l_status)
			window.set_root (l_root)

				-- The agents come LAST: an agent on Current lets Current
				-- escape, so every attribute is set before one is made.
			l_bar.add_menu (Text_menu_file, agent file_menu)
			l_bar.add_menu (Text_menu_edit, agent edit_menu)
			l_bar.add_menu (Text_menu_block, agent block_menu)
			l_bar.add_menu (Text_menu_voice, agent voice_menu)
			l_bar.add_menu (Text_menu_render, agent render_menu)
			l_bar.add_menu (Text_menu_export, agent export_menu)
			l_bar.add_menu (Text_menu_help, agent help_menu)
			window.set_menu_bar (l_bar)
		ensure
			shaped: attached window.shaping
			no_essay: not has_essay
			every_zone_empty: dock.panels.is_empty
			seven_pads: menu_bar.labels.count = 7
			publish_blocked: not publish_button.is_enabled
		end

feature -- Access

	window: SW_WINDOW
			-- The one window; nothing native until `run'.

	theme: SW_THEME
			-- SW_THEME.make_light: the style_spec section 2 tokens.

	menu_bar: SW_MENU_BAR
			-- File / Edit / Block / Voice / Render / Export / Help.

	toolbar: SW_TOOLBAR
			-- Undo, redo; render dirty, run the gate. All greyed in step 1.

	breadcrumb: SW_LABEL
			-- Project / essay - the author's title, shaped.

	publish_button: SW_BUTTON
			-- Publish, carrying its blocker as its label while disabled.

	dock: SW_DOCK_HOST
			-- West, east and south zones around the centre. Empty zones
			-- collapse to nothing, so in step 1 the centre is the frame.

	status_bar: SW_STATUS_BAR
			-- Left: the room's state in words. Right: engine / voice.

	has_essay: BOOLEAN
			-- Is an essay open? Step 1 cannot open one.

	fonts_registered: INTEGER
			-- How many of the three theme faces `register_fonts' loaded.

	title: STRING_32
			-- What the breadcrumb shows.
		do
			Result := breadcrumb.text
		ensure
			the_breadcrumb: Result.same_string (breadcrumb.text)
		end

feature -- Element change

	show_title (a_title: READABLE_STRING_GENERAL)
			-- Put `a_title' in the breadcrumb, whatever its script.
		require
			named: not a_title.is_empty
		do
			breadcrumb.set_text (a_title)
		ensure
			shown: title.same_string_general (a_title)
		end

feature -- Operation

	run
			-- Show the window and pump until it closes.
		do
			window.run
		end

	close
			-- Close the native window, when there is one.
		do
			if window.hwnd /= default_pointer then
				window.close
			end
		end

	show_about
			-- What Help > About says.
		do
			window.toast (Text_about, 1)
		end

feature -- Menus, built fresh on every open

	file_menu: SW_MENU
			-- Open essay (step 2), Exit.
		do
			create Result.make
			Result.add_item (Text_item_open, Text_key_open, False, Void)
			Result.add_separator
			Result.add_item (Text_item_exit, Text_key_exit, True, agent close)
		ensure
			exit_offered: Result.items.last.enabled
		end

	edit_menu: SW_MENU
			-- Undo / Redo (session history, spec.md section 8.3).
		do
			create Result.make
			Result.add_item (Text_item_undo, Text_key_undo, False, Void)
			Result.add_item (Text_item_redo, Text_key_redo, False, Void)
		end

	block_menu: SW_MENU
			-- New take, split at caret, lock (F1.2).
		do
			create Result.make
			Result.add_item (Text_item_new_take, "", False, Void)
			Result.add_item (Text_item_split, "", False, Void)
			Result.add_item (Text_item_lock, "", False, Void)
		end

	voice_menu: SW_MENU
			-- Assign a slot to the selection (S3.3).
		do
			create Result.make
			Result.add_item (Text_item_assign_voice, "", False, Void)
		end

	render_menu: SW_MENU
			-- Render what is dirty; run the gate.
		do
			create Result.make
			Result.add_item (Text_item_render_dirty, "", False, Void)
			Result.add_item (Text_item_run_gate, "", False, Void)
		end

	export_menu: SW_MENU
			-- Publish; the EDL (Phase S4).
		do
			create Result.make
			Result.add_item (Text_item_publish, "", False, Void)
			Result.add_item (Text_item_export_edl, "", False, Void)
		end

	help_menu: SW_MENU
		do
			create Result.make
			Result.add_item (Text_item_about, "", True, agent show_about)
		ensure
			about_offered: Result.items.last.enabled
		end

feature {NONE} -- Fonts

	register_fonts
			-- Load Archivo, Literata and IBM Plex Mono for this process
			-- from `font_directory', counting what took. A face that did
			-- not load falls back to the family Windows substitutes
			-- (Segoe UI, Georgia, Consolas) - the theme's names stay.
		local
			l_dir: STRING_32
		do
			l_dir := font_directory
			if not l_dir.is_empty then
				across
					Font_files as ic
				loop
					if window.add_font (l_dir + "\" + ic) then
						fonts_registered := fonts_registered + 1
					end
				end
			end
		ensure
			at_most_three: fonts_registered >= 0 and fonts_registered <= Font_files.count
		end

	font_directory: STRING_32
			-- The `fonts' folder beside the running executable (a shipped
			-- Studio), else the repository's own under $SIMPLE_EIFFEL;
			-- empty when neither is there.
		local
			l_env: EXECUTION_ENVIRONMENT
			l_exe, l_candidate: PATH
			l_dir: DIRECTORY
		do
			create Result.make_empty
			create l_env
			create l_exe.make_from_string (l_env.arguments.command_name)
			l_candidate := l_exe.parent.extended ("fonts")
			create l_dir.make_with_path (l_candidate)
			if l_dir.exists then
				Result := l_candidate.name.to_string_32
			elseif attached l_env.item ("SIMPLE_EIFFEL") as al_root and then not al_root.is_empty then
				l_candidate := (create {PATH}.make_from_string (al_root)).extended ("simple_narrate").extended ("fonts")
				create l_dir.make_with_path (l_candidate)
				if l_dir.exists then
					Result := l_candidate.name.to_string_32
				end
			end
		end

	Font_files: ARRAY [STRING_32]
			-- The three vendored faces, in the theme's role order.
		once
			Result := <<{STRING_32} "Archivo.ttf", {STRING_32} "Literata.ttf", {STRING_32} "IBMPlexMono.ttf">>
		ensure
			three: Result.count = 3
		end

feature -- Constants

	Window_title: STRING_32 = "simple_narrate Studio"

	Text_scale: REAL_64 = 1.5
			-- Readability first: half again the library's own sizes.

	Text_no_essay: STRING_32 = "No essay open"
	Text_publish_blocked: STRING_32 = "Publish %/8211/ no essay open"
	Text_empty_title: STRING_32 = "Nothing to narrate yet"
	Text_empty_message: STRING_32 = "Open an essay (File %/8250/ Open essay) and its blocks will stand here."
	Text_status_idle: STRING_32 = "no essay %/183/ 0 dirty %/183/ 0 pending"
	Text_engine_none: STRING_32 = "engine %/8212/"
	Text_about: STRING_32 = "simple_narrate Studio %/8212/ the shell (Phase S2, step 1). Nothing leaves this machine."

	Text_undo: STRING_32 = "Undo"
	Text_undo_hint: STRING_32 = "Undo the last operation (Ctrl+Z)"
	Text_redo: STRING_32 = "Redo"
	Text_redo_hint: STRING_32 = "Redo (Ctrl+Y)"
	Text_render_dirty: STRING_32 = "Render dirty"
	Text_render_dirty_hint: STRING_32 = "Render every stale block through the worker"
	Text_gate: STRING_32 = "Gate"
	Text_gate_hint: STRING_32 = "Run the fidelity gate over every take"

	Text_menu_file: STRING_32 = "&File"
	Text_menu_edit: STRING_32 = "&Edit"
	Text_menu_block: STRING_32 = "&Block"
	Text_menu_voice: STRING_32 = "&Voice"
	Text_menu_render: STRING_32 = "&Render"
	Text_menu_export: STRING_32 = "E&xport"
	Text_menu_help: STRING_32 = "&Help"

	Text_item_open: STRING_32 = "&Open essay%/8230/"
	Text_key_open: STRING_32 = "Ctrl+O"
	Text_item_exit: STRING_32 = "E&xit"
	Text_key_exit: STRING_32 = "Alt+F4"
	Text_item_undo: STRING_32 = "&Undo"
	Text_key_undo: STRING_32 = "Ctrl+Z"
	Text_item_redo: STRING_32 = "&Redo"
	Text_key_redo: STRING_32 = "Ctrl+Y"
	Text_item_new_take: STRING_32 = "&New take"
	Text_item_split: STRING_32 = "&Split at caret"
	Text_item_lock: STRING_32 = "&Lock"
	Text_item_assign_voice: STRING_32 = "&Assign voice%/8230/"
	Text_item_render_dirty: STRING_32 = "Render &dirty"
	Text_item_run_gate: STRING_32 = "Run the &gate"
	Text_item_publish: STRING_32 = "&Publish%/8230/"
	Text_item_export_edl: STRING_32 = "Export &EDL%/8230/"
	Text_item_about: STRING_32 = "&About the Studio"

invariant
	shaped_text_on: attached window.shaping
	seven_pads: menu_bar.labels.count = 7
	fonts_counted: fonts_registered >= 0 and fonts_registered <= 3
	no_essay_in_step_one: not has_essay

end
