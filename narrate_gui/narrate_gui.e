note
	description: "[
		The narrate editor - the reference render (docs/_artwork/
		01-editor-window.png) drawn live by simple_cairo through the pure
		Win32 pump, no Vision2, and now INTERACTIVE: a real text engine
		with caret, selection (click, drag, double-click word, shift and
		arrows), live split-preview tint at the caret, and block actions
		(Split Here, Approve, Up, Down) on a dynamic block model.

		The window keeps to the LEFT HALF of the desktop by construction:
		the capture rig owns the right half while it reads.
	]"

class
	NARRATE_GUI

create
	make

feature {NONE} -- Window metrics

	Win_x: INTEGER = 8
	Win_y: INTEGER = 8
	Win_w: INTEGER = 1880
	Win_h: INTEGER = 1980
			-- Left half of a 3840x2160 desktop, taskbar spared.

	Bar_h: REAL_64 = 64.0
	Status_h: REAL_64 = 36.0
	Rail_w: REAL_64 = 100.0
	Right_w: REAL_64 = 455.0
	Line_h: REAL_64 = 26.0

feature {NONE} -- Tokens (style_spec section 2, verbatim - do not retune)

	C_bg: NATURAL_32 = 0xFFE9ECF1
	C_surface: NATURAL_32 = 0xFFFFFFFF
	C_variant: NATURAL_32 = 0xFFF5F7FA
	C_outline: NATURAL_32 = 0xFFD3DAE3
	C_ink: NATURAL_32 = 0xFF1A2029
	C_ink2: NATURAL_32 = 0xFF5A6573

	S_approved: NATURAL_32 = 0xFF1D6B52
	S_rendered: NATURAL_32 = 0xFF1F5FA8
	S_dirty: NATURAL_32 = 0xFF8A5A0B
	S_failed: NATURAL_32 = 0xFFAF3A22
	S_new: NATURAL_32 = 0xFFD3DAE3

	W_approved: NATURAL_32 = 0xFFE0F0E9
	W_rendered: NATURAL_32 = 0xFFC7DAF1
	W_dirty: NATURAL_32 = 0xFFFAF1DD
	W_failed: NATURAL_32 = 0xFFF8E7E2

	F_ui: STRING_32
		once
			create Result.make_from_string_general ("Archivo")
		end

	F_text: STRING_32
		once
			create Result.make_from_string_general ("Literata")
		end

	F_mono: STRING_32
		once
			create Result.make_from_string_general ("IBM Plex Mono")
		end

feature {NONE} -- Initialization

	make
		local
			ns: NATIVE_STRING
			quit: BOOLEAN
			ev: INTEGER
		do
			create cairo.make
			create ev_buf.make (16)
			create blocks.make (8)
			create btn_zones.make (40)
			create text_zones.make (8)
			create lay_x.make (400)
			create lay_adv.make (400)
			create lay_line.make (400)
			create bold_flags.make (400)
			log_line ({STRING_32} "narrate shell starting")
			load_fonts
			seed_blocks
			offscreen := cairo.create_surface (Win_w, Win_h)
			create ctx.make (offscreen)
			focused := 2
			caret := 103
			sel_anchor := caret
			build_layout
			render
			if offscreen.write_png ({STRING_32} "narrate_first_frame.png") then
				log_line ({STRING_32} "first frame written")
			end
			create ns.make ({STRING_32} "simple_narrate")
			hwnd := c_create_window (ns.item, Win_x, Win_y, Win_w, Win_h)
			if hwnd = default_pointer then
				log_line ({STRING_32} "window creation FAILED")
			else
				log_line ({STRING_32} "narrate face up (left half)")
				from
				until
					quit
				loop
					if c_pump = 0 then
						quit := True
					end
					from
						ev := c_next_event (ev_buf.item)
					until
						ev = 0
					loop
						handle_event (ev, ev_buf.read_integer_32 (4), ev_buf.read_integer_32 (8))
						ev := c_next_event (ev_buf.item)
					end
				end
			end
			log_line ({STRING_32} "session closed")
			ctx.destroy
			offscreen.destroy
		end

	seed_blocks
		local
			b: NARRATE_BLOCK
		do
			create b.make (7, {STRING_32} "HEADING", {STRING_32} "APPROVED", {STRING_32} "0.98",
				{STRING_32} "", {STRING_32} "The Day Yahweh Looked Defeated")
			blocks.extend (b)
			create b.make (8, {STRING_32} "PROSE", {STRING_32} "DIRTY", {STRING_32} "",
				{STRING_32} "60-word sentence",
				{STRING_32} "And he%/8217/s smart about it, too. He doesn%/8217/t overreach. He doesn%/8217/t claim the whole Bible is !one long lie!. He does the thing that actually works on thoughtful people, which is to say: I%/8217/m not asking you to distrust the text. I%/8217/m asking you to read it more honestly than your !pastor! does.")
			blocks.extend (b)
			create b.make (9, {STRING_32} "PROSE", {STRING_32} "RENDERED", {STRING_32} "0.94",
				{STRING_32} "",
				{STRING_32} "He points at the stone, then at 2 Kings 3, then back at the stone, and he lets the two of them argue with each other while !he! stands off to the side looking reasonable.")
			blocks.extend (b)
			create b.make (10, {STRING_32} "SEPARATOR", {STRING_32} "FAILED", {STRING_32} "",
				{STRING_32} "engine: CUDA out of memory",
				{STRING_32} "The Leash %/183/ The Day Yahweh Looked Defeated %/183/ And One Called Mercy")
			blocks.extend (b)
		end

feature {NONE} -- Event handling

	handle_event (a_type, a_x, a_y: INTEGER)
		do
			inspect a_type
			when 2 then
				on_click (a_x, a_y)
			when 3 then
				on_char (a_x)
			when 4 then
				on_key (a_x)
			when 6 then
				blit
			when 8 then
				on_double_click (a_x, a_y)
			when 9 then
				on_drag (a_x, a_y)
			when 10 then
				dragging := False
			else
			end
		end

	on_click (a_x, a_y: INTEGER)
		local
			i: INTEGER
			hit: BOOLEAN
		do
			from
				i := 1
			until
				i > btn_zones.count or hit
			loop
				if attached btn_zones.i_th (i) as z and then
					a_x >= z.x and then a_x <= z.x + z.w and then a_y >= z.y and then a_y <= z.y + z.h
				then
					hit := True
					do_action (z.action, z.block)
				end
				i := i + 1
			end
			from
				i := 1
			until
				i > text_zones.count or hit
			loop
				if attached text_zones.i_th (i) as z and then
					a_x >= z.x and then a_x <= z.x + z.w and then a_y >= z.y and then a_y <= z.y + z.h
				then
					hit := True
					if focused /= z.block then
						focused := z.block
						build_layout
					end
					caret := offset_at (a_x, a_y)
					sel_anchor := caret
					dragging := True
					refresh
				end
				i := i + 1
			end
		end

	on_drag (a_x, a_y: INTEGER)
		do
			if dragging and focused > 0 then
				caret := offset_at (a_x, a_y)
				refresh
			end
		end

	on_double_click (a_x, a_y: INTEGER)
			-- Select the word under the point.
		local
			c, lo, hi, n: INTEGER
			t: STRING_32
		do
			if focused > 0 then
				t := blocks.i_th (focused).text
				n := t.count
				c := offset_at (a_x, a_y)
				if n > 0 then
					lo := c.max (1).min (n)
					hi := lo
					from
					until
						lo <= 1 or else t.item (lo - 1) = ' '
					loop
						lo := lo - 1
					end
					from
					until
						hi >= n or else t.item (hi + 1) = ' '
					loop
						hi := hi + 1
					end
					sel_anchor := lo - 1
					caret := hi
					dragging := False
					refresh
					log_line ({STRING_32} "word selected: " + t.substring (lo, hi))
				end
			end
		end

	on_char (a_code: INTEGER)
		local
			b: NARRATE_BLOCK
			t: STRING_32
		do
			if focused > 0 then
				b := blocks.i_th (focused)
				t := b.text
				if a_code = 8 then
					if has_selection then
						delete_selection
					elseif caret > 0 then
						t.remove (caret)
						caret := caret - 1
						sel_anchor := caret
					end
					b.mark_dirty
					edited
				elseif a_code >= 32 then
					if has_selection then
						delete_selection
						t := b.text
					end
					t.insert_character (a_code.to_character_32, caret + 1)
					caret := caret + 1
					sel_anchor := caret
					b.mark_dirty
					edited
				end
			end
		end

	on_key (a_vk: INTEGER)
		local
			b: NARRATE_BLOCK
			n: INTEGER
			ext: BOOLEAN
			cl, cx_line: INTEGER
			cx: REAL_64
		do
			if focused > 0 then
				b := blocks.i_th (focused)
				n := b.text.count
				ext := c_shift_down = 1
				inspect a_vk
				when 37 then -- LEFT
					caret := (caret - 1).max (0)
				when 39 then -- RIGHT
					caret := (caret + 1).min (n)
				when 36 then -- HOME
					cl := caret_line
					caret := line_start (cl)
				when 35 then -- END
					cl := caret_line
					caret := line_end (cl)
				when 38 then -- UP
					cl := caret_line
					if cl > 0 then
						cx := caret_x
						caret := offset_on_line (cl - 1, cx)
					end
				when 40 then -- DOWN
					cl := caret_line
					if cl < lay_lines - 1 then
						cx := caret_x
						caret := offset_on_line (cl + 1, cx)
					end
				when 46 then -- DELETE
					if has_selection then
						delete_selection
						b.mark_dirty
						edited
					elseif caret < n then
						b.text.remove (caret + 1)
						b.mark_dirty
						edited
					end
					cx_line := 0
				else
				end
				if a_vk /= 46 then
					if not ext then
						sel_anchor := caret
					end
					refresh
				end
			end
		end

	do_action (a_action, a_block: INTEGER)
		do
			inspect a_action
			when 4 then
				do_split (a_block)
			when 5 then
				do_move (a_block, -1)
			when 6 then
				do_move (a_block, 1)
			when 3 then
				if blocks.i_th (a_block).state.same_string ("RENDERED") then
					blocks.i_th (a_block).set_state ({STRING_32} "APPROVED")
					log_line ({STRING_32} "approved block " + blocks.i_th (a_block).ordinal.out)
					refresh
				end
			when 7 then
				blocks.i_th (a_block).set_state ({STRING_32} "DIRTY")
				log_line ({STRING_32} "retry queued for block " + blocks.i_th (a_block).ordinal.out)
				refresh
			when 1 then
				log_line ({STRING_32} "play requested (engine not wired)")
			when 2 then
				log_line ({STRING_32} "new take requested (engine not wired)")
			else
			end
		end

	do_split (a_block: INTEGER)
			-- Split the block at the caret. Takes a caret, not a
			-- selection - the spec's design principle. Warns, never
			-- blocks, on a mid-sentence point.
		local
			b, nb: NARRATE_BLOCK
			left, right: STRING_32
			n: INTEGER
		do
			if a_block = focused and focused > 0 then
				b := blocks.i_th (focused)
				n := b.text.count
				if caret > 0 and caret < n then
					left := b.text.substring (1, caret)
					right := b.text.substring (caret + 1, n)
					left.prune_all_trailing (' ')
					right.prune_all_leading (' ')
					if not left.is_empty and then left.item (left.count) /= '.' then
						log_line ({STRING_32} "warning: split lands mid-sentence (allowed)")
					end
					b.set_text (left)
					b.mark_dirty
					create nb.make (b.ordinal + 1, b.kind.twin, {STRING_32} "DIRTY",
						{STRING_32} "", {STRING_32} "", right)
					blocks.go_i_th (focused)
					blocks.put_right (nb)
					renumber
					caret := left.count
					sel_anchor := caret
					build_layout
					refresh
					log_line ({STRING_32} "split block " + b.ordinal.out + " at " + caret.out)
				else
					log_line ({STRING_32} "split needs the caret inside the text")
				end
			else
				log_line ({STRING_32} "split acts on the focused block")
			end
		end

	do_move (a_block, a_delta: INTEGER)
			-- Free - no re-render (spec 8.2): order changes nothing
			-- about any block's audio.
		local
			j: INTEGER
		do
			j := a_block + a_delta
			if j >= 1 and j <= blocks.count then
				blocks.go_i_th (a_block)
				blocks.swap (j)
				renumber
				if focused = a_block then
					focused := j
				elseif focused = j then
					focused := a_block
				end
				refresh
				log_line ({STRING_32} "moved block to slot " + j.out)
			end
		end

	renumber
		local
			i: INTEGER
		do
			from
				i := 1
			until
				i > blocks.count
			loop
				blocks.i_th (i).set_ordinal (6 + i)
				i := i + 1
			end
		end

	edited
		do
			build_layout
			refresh
		end

	refresh
		do
			render
			blit
			offscreen.write_png ({STRING_32} "narrate_first_frame.png").do_nothing
		end

feature {NONE} -- Text engine: layout

	lay_x: ARRAYED_LIST [REAL_64]
			-- Left edge of each character of the focused block's text.

	lay_adv: ARRAYED_LIST [REAL_64]
			-- Advance of each character.

	lay_line: ARRAYED_LIST [INTEGER]
			-- Zero-based wrapped line of each character.

	bold_flags: ARRAYED_LIST [BOOLEAN]
			-- Emphasis per character, from the !marker! syntax.

	lay_lines: INTEGER
			-- Wrapped line count of the focused text (at least 1).

	wrap_w: REAL_64
		do
			Result := card_w - 44.0
		end

	build_layout
			-- Measure-then-place: per-character positions for the focused
			-- block, greedy word wrap. Spaces never trigger a wrap.
		local
			t: STRING_32
			n, i, j, k, line: INTEGER
			x, ww: REAL_64
		do
			lay_x.wipe_out
			lay_adv.wipe_out
			lay_line.wipe_out
			build_bold
			lay_lines := 1
			if focused > 0 then
				t := blocks.i_th (focused).text
				n := t.count
				from
					i := 1
					x := 0.0
					line := 0
				until
					i > n
				loop
					if t.item (i) = ' ' then
						prose_font (i)
						lay_x.extend (x)
						lay_adv.extend (adv ({STRING_32} " "))
						lay_line.extend (line)
						x := x + lay_adv.last
						i := i + 1
					else
						from
							j := i
						until
							j >= n or else t.item (j + 1) = ' '
						loop
							j := j + 1
						end
						ww := 0.0
						from
							k := i
						until
							k > j
						loop
							prose_font (k)
							ww := ww + adv (t.substring (k, k))
							k := k + 1
						end
						if x > 0.0 and then x + ww > wrap_w then
							line := line + 1
							x := 0.0
						end
						from
							k := i
						until
							k > j
						loop
							prose_font (k)
							lay_x.extend (x)
							lay_adv.extend (adv (t.substring (k, k)))
							lay_line.extend (line)
							x := x + lay_adv.last
							k := k + 1
						end
						i := j + 1
					end
				end
				lay_lines := line + 1
			end
		ensure
			one_slot_per_char: focused > 0 implies lay_x.count = blocks.i_th (focused).text.count
		end

	build_bold
		local
			t: STRING_32
			i, n: INTEGER
			in_b: BOOLEAN
		do
			bold_flags.wipe_out
			if focused > 0 then
				t := blocks.i_th (focused).text
				n := t.count
				from
					i := 1
				until
					i > n
				loop
					if t.item (i) = '!' then
						if in_b then
							bold_flags.extend (True)
							in_b := False
						elseif t.index_of ('!', i + 1) > 0 then
							bold_flags.extend (True)
							in_b := True
						else
							bold_flags.extend (False)
						end
					else
						bold_flags.extend (in_b)
					end
					i := i + 1
				end
			end
		end

	prose_font (a_char_index: INTEGER)
			-- The measuring and drawing font for character `a_char_index'
			-- of the focused block: family by kind, weight by emphasis.
		local
			fam: STRING_32
		do
			if focused > 0 and then blocks.i_th (focused).kind.same_string ("PROSE") then
				fam := F_text
			elseif focused > 0 and then blocks.i_th (focused).kind.same_string ("HEADING") then
				fam := F_text
			else
				fam := F_text
			end
			font (fam, 13.5,
				a_char_index >= 1 and a_char_index <= bold_flags.count and then bold_flags.i_th (a_char_index))
		end

	caret_line: INTEGER
		do
			if caret > 0 and caret <= lay_line.count then
				Result := lay_line.i_th (caret)
			elseif not lay_line.is_empty and caret = 0 then
				Result := lay_line.first
			end
		end

	caret_x: REAL_64
		do
			if caret > 0 and caret <= lay_x.count then
				Result := lay_x.i_th (caret) + lay_adv.i_th (caret)
			end
		end

	line_start (a_line: INTEGER): INTEGER
		local
			i: INTEGER
		do
			from
				i := 1
			until
				i > lay_line.count or else lay_line.i_th (i) = a_line
			loop
				i := i + 1
			end
			Result := (i - 1).max (0)
		end

	line_end (a_line: INTEGER): INTEGER
		local
			i: INTEGER
		do
			Result := lay_line.count
			from
				i := 1
			until
				i > lay_line.count
			loop
				if lay_line.i_th (i) = a_line then
					Result := i
				end
				i := i + 1
			end
		end

	offset_on_line (a_line: INTEGER; a_px: REAL_64): INTEGER
			-- Caret offset nearest `a_px' on wrapped line `a_line'.
		local
			i: INTEGER
			found_any: BOOLEAN
		do
			Result := lay_line.count
			from
				i := 1
			until
				i > lay_line.count
			loop
				if lay_line.i_th (i) = a_line then
					if not found_any and then a_px < lay_x.i_th (i) + lay_adv.i_th (i) / 2.0 then
						Result := i - 1
						found_any := True
					elseif a_px >= lay_x.i_th (i) + lay_adv.i_th (i) / 2.0 then
						Result := i
					end
				end
				i := i + 1
			end
		ensure
			in_range: Result >= 0 and Result <= lay_line.count
		end

	offset_at (a_x, a_y: INTEGER): INTEGER
			-- Character offset under a window point, for the focused block.
		local
			line: INTEGER
			tx, ty: REAL_64
		do
			if focused > 0 and focused <= text_zones.count and then attached text_zones.i_th (focused) as z then
				tx := a_x - z.x
				ty := a_y - z.y
				line := (ty / Line_h).truncated_to_integer.max (0).min (lay_lines - 1)
				Result := offset_on_line (line, tx)
			end
		ensure
			in_range: Result >= 0 and (focused > 0 implies Result <= blocks.i_th (focused).text.count)
		end

	has_selection: BOOLEAN
		do
			Result := sel_anchor /= caret
		end

	delete_selection
		local
			lo, hi: INTEGER
			b: NARRATE_BLOCK
		do
			if focused > 0 then
				b := blocks.i_th (focused)
				lo := sel_anchor.min (caret)
				hi := sel_anchor.max (caret)
				b.text.remove_substring (lo + 1, hi)
				caret := lo
				sel_anchor := lo
			end
		ensure
			collapsed: not has_selection
		end

feature {NONE} -- Rendering

	render
		do
			btn_zones.wipe_out
			text_zones.wipe_out
			set_col (C_bg)
			ctx.paint.do_nothing
			draw_toolbar
			draw_map_rail
			draw_block_list
			draw_right_rail
			draw_status_bar
		end

	draw_toolbar
		local
			x: REAL_64
		do
			set_col (C_variant)
			ctx.rectangle (0.0, 0.0, Win_w, Bar_h).fill.do_nothing
			hline (0.0, Bar_h - 1.0, Win_w)
			font (F_ui, 15.0, True)
			set_col (C_ink)
			txt (20.0, 40.0, {STRING_32} "The Day Yahweh Looked Defeated")
			x := 20.0 + adv ({STRING_32} "The Day Yahweh Looked Defeated") + 16.0
			font (F_mono, 11.0, False)
			set_col (C_ink2)
			txt (x, 39.0, {STRING_32} "chatterbox %/183/ andrew %/183/ gate 0.95")
			x := x + adv ({STRING_32} "chatterbox %/183/ andrew %/183/ gate 0.95") + 28.0
			x := button (x, 16.0, {STRING_32} "Undo", True, False)
			x := button (x + 8.0, 16.0, {STRING_32} "Redo", False, False)
			x := x + 20.0
			x := button (x, 16.0, {STRING_32} "Render Dirty (12)", True, False)
			x := button (x + 8.0, 16.0, {STRING_32} "Run Gate", False, False)
			draw_publish_blocked
		end

	draw_publish_blocked
		local
			w: REAL_64
			lx: REAL_64
		do
			font (F_ui, 12.0, True)
			w := adv ({STRING_32} "Publish") + 20.0
			font (F_mono, 11.0, False)
			w := w + adv ({STRING_32} "blocked %/183/ 12 unapproved %/183/ fidelity 0.87") + 22.0
			set_col (W_failed)
			fill_rrect (Win_w - 20.0 - w, 14.0, w, 36.0, 3.0)
			set_col (S_failed)
			stroke_rrect (Win_w - 20.0 - w + 0.5, 14.5, w - 1.0, 35.0, 3.0)
			lx := Win_w - 20.0 - w + 11.0
			font (F_ui, 12.0, True)
			txt (lx, 37.0, {STRING_32} "Publish")
			lx := lx + adv ({STRING_32} "Publish") + 9.0
			font (F_mono, 11.0, False)
			txt (lx, 36.0, {STRING_32} "blocked %/183/ 12 unapproved %/183/ fidelity 0.87")
		end

	state_color (a_state: READABLE_STRING_32): NATURAL_32
		do
			if a_state.same_string ("APPROVED") then
				Result := S_approved
			elseif a_state.same_string ("RENDERED") then
				Result := S_rendered
			elseif a_state.same_string ("DIRTY") then
				Result := S_dirty
			elseif a_state.same_string ("FAILED") then
				Result := S_failed
			else
				Result := S_new
			end
		end

	state_wash (a_state: READABLE_STRING_32): NATURAL_32
		do
			if a_state.same_string ("APPROVED") then
				Result := W_approved
			elseif a_state.same_string ("RENDERED") then
				Result := W_rendered
			elseif a_state.same_string ("DIRTY") then
				Result := W_dirty
			elseif a_state.same_string ("FAILED") then
				Result := W_failed
			else
				Result := C_variant
			end
		end

	draw_map_rail
		local
			i, col, row: INTEGER
			cx, cy, ly: REAL_64
			cell_state: NATURAL_32
		do
			set_col (C_variant)
			ctx.rectangle (0.0, Bar_h, Rail_w, Win_h - Bar_h - Status_h).fill.do_nothing
			vline (Rail_w - 1.0, Bar_h, Win_h - Bar_h - Status_h)
			font (F_mono, 10.0, False)
			set_col (C_ink2)
			txt (16.0, Bar_h + 26.0, {STRING_32} "MAP")
			from
				i := 1
			until
				i > 36
			loop
				col := (i - 1) \\ 3
				row := (i - 1) // 3
				cx := 16.0 + col * 24.0
				cy := Bar_h + 40.0 + row * 24.0
				if i <= blocks.count then
					cell_state := state_color (blocks.i_th (i).state)
				elseif i <= 30 then
					cell_state := demo_cell (i)
				else
					cell_state := S_new
				end
				set_col (cell_state)
				fill_rrect (cx, cy, 18.0, 18.0, 3.0)
				if i = focused then
					set_col (C_ink)
					stroke_rrect (cx - 1.5, cy - 1.5, 21.0, 21.0, 4.0)
				end
				i := i + 1
			end
			ly := Win_h - Status_h - 128.0
			legend_row (ly, S_approved, {STRING_32} "approved")
			legend_row (ly + 22.0, S_rendered, {STRING_32} "rendered")
			legend_row (ly + 44.0, S_dirty, {STRING_32} "dirty")
			legend_row (ly + 66.0, S_failed, {STRING_32} "failed")
			legend_row (ly + 88.0, S_new, {STRING_32} "new")
		end

	demo_cell (a_i: INTEGER): NATURAL_32
		local
			m: INTEGER
		do
			m := a_i \\ 7
			if m = 2 then
				Result := S_rendered
			elseif m = 4 then
				Result := S_dirty
			elseif m = 6 and a_i = 13 then
				Result := S_failed
			else
				Result := S_approved
			end
		end

	legend_row (a_y: REAL_64; a_col: NATURAL_32; a_label: STRING_32)
		do
			set_col (a_col)
			fill_rrect (16.0, a_y, 11.0, 11.0, 2.0)
			font (F_mono, 9.0, False)
			set_col (C_ink2)
			txt (33.0, a_y + 10.0, a_label)
		end

feature {NONE} -- Rendering: the block list

	Card_x: REAL_64 = 124.0

	card_w: REAL_64
		do
			Result := Win_w - Right_w - Card_x - 24.0
		end

	lines_of (a_text: STRING_32): INTEGER
			-- Wrapped line count of `a_text' at wrap_w, plain weight.
		local
			n, i, j, k, line: INTEGER
			x, ww: REAL_64
		do
			font (F_text, 13.5, False)
			n := a_text.count
			from
				i := 1
				x := 0.0
				line := 0
			until
				i > n
			loop
				if a_text.item (i) = ' ' then
					x := x + adv ({STRING_32} " ")
					i := i + 1
				else
					from
						j := i
					until
						j >= n or else a_text.item (j + 1) = ' '
					loop
						j := j + 1
					end
					ww := 0.0
					from
						k := i
					until
						k > j
					loop
						ww := ww + adv (a_text.substring (k, k))
						k := k + 1
					end
					if x > 0.0 and then x + ww > wrap_w then
						line := line + 1
						x := 0.0
					end
					x := x + ww
					i := j + 1
				end
			end
			Result := line + 1
		ensure
			at_least_one: Result >= 1
		end

	block_height (a_index: INTEGER): REAL_64
		local
			nl: INTEGER
		do
			if a_index = focused then
				nl := lay_lines
			else
				nl := lines_of (blocks.i_th (a_index).text)
			end
			Result := 44.0 + nl * Line_h + 12.0 + 56.0
		end

	draw_block_list
		local
			i: INTEGER
			y: REAL_64
		do
			y := Bar_h + 20.0
			from
				i := 1
			until
				i > blocks.count
			loop
				y := draw_block (i, y) + 14.0
				i := i + 1
			end
		end

	draw_block (a_index: INTEGER; a_y: REAL_64): REAL_64
			-- Draw block `a_index' at `a_y'; return its bottom.
		local
			b: NARRATE_BLOCK
			h, x, bx, by: REAL_64
			sc: NATURAL_32
		do
			b := blocks.i_th (a_index)
			h := block_height (a_index)
			sc := state_color (b.state)
			set_col (C_surface)
			fill_rrect (Card_x, a_y, card_w, h, 3.0)
			if a_index = focused then
				set_col (S_rendered)
				ctx.set_line_width (2.0).do_nothing
				rrect_path (Card_x - 1.0, a_y - 1.0, card_w + 2.0, h + 2.0, 4.0)
				ctx.stroke.do_nothing
				ctx.set_line_width (1.0).do_nothing
			else
				set_col (C_outline)
				stroke_rrect (Card_x + 0.5, a_y + 0.5, card_w - 1.0, h - 1.0, 3.0)
			end
			set_col (sc)
			ctx.rectangle (Card_x, a_y + 3.0, 4.0, h - 6.0).fill.do_nothing

			x := Card_x + 22.0
			font (F_mono, 11.0, False)
			set_col (C_ink2)
			txt (x, a_y + 30.0, two_digits (b.ordinal))
			x := x + adv (two_digits (b.ordinal)) + 12.0
			x := chip (x, a_y + 16.0, b.kind, C_ink2, C_variant, C_outline)
			x := chip (x + 8.0, a_y + 16.0, b.state, sc, state_wash (b.state), sc)
			if not b.fid.is_empty then
				font (F_mono, 11.0, False)
				set_col (C_ink)
				txt (x + 12.0, a_y + 30.0, b.fid)
				x := x + 12.0 + adv (b.fid)
			end
			if not b.warn.is_empty then
				font (F_mono, 10.0, False)
				set_col (S_dirty)
				txt (x + 16.0, a_y + 29.0, {STRING_32} "%/8212/  " + b.warn)
			end

			draw_block_text (a_index, a_y + 44.0)

			by := a_y + h - 44.0
			bx := Card_x + 20.0
			bx := zone_button (bx, by, {STRING_32} "Play",
				b.state.same_string ("APPROVED") or b.state.same_string ("RENDERED"), False, a_index, 1)
			bx := zone_button (bx + 8.0, by, {STRING_32} "New Take", True, False, a_index, 2)
			if b.state.same_string ("FAILED") then
				bx := zone_button (bx + 8.0, by, {STRING_32} "Retry", True, True, a_index, 7)
			else
				bx := zone_button (bx + 8.0, by, {STRING_32} "Approve",
					b.state.same_string ("RENDERED"), b.state.same_string ("RENDERED"), a_index, 3)
			end
			bx := zone_button (bx + 20.0, by, {STRING_32} "Split Here", a_index = focused,
				a_index = focused, a_index, 4)
			bx := zone_button (bx + 8.0, by, {STRING_32} "Up", a_index > 1, False, a_index, 5)
			bx := zone_button (bx + 8.0, by, {STRING_32} "Down", a_index < blocks.count, False, a_index, 6)
			Result := a_y + h
		end

	draw_block_text (a_index: INTEGER; a_top: REAL_64)
			-- The prose area. For the focused block: per-character engine
			-- rendering - tint split at the caret, selection, emphasis,
			-- the caret bar itself. Others: plain wrapped text.
		local
			b: NARRATE_BLOCK
			t: STRING_32
			i, n, lo, hi: INTEGER
			x, y, w, cxx: REAL_64
			zone_h: REAL_64
			tint: NATURAL_32
			seln: BOOLEAN
		do
			b := blocks.i_th (a_index)
			t := b.text
			n := t.count
			if a_index = focused then
				zone_h := lay_lines * Line_h
			else
				zone_h := lines_of (t) * Line_h
			end
			if text_zones.count < a_index then
				from
				until
					text_zones.count >= a_index
				loop
					text_zones.extend ([0.0, 0.0, 0.0, 0.0, text_zones.count + 1])
				end
			end
			text_zones.put_i_th ([Card_x + 22.0, a_top, wrap_w, zone_h, a_index], a_index)

			if a_index = focused then
				lo := sel_anchor.min (caret)
				hi := sel_anchor.max (caret)
				from
					i := 1
				until
					i > n
				loop
					x := Card_x + 22.0 + lay_x.i_th (i)
					y := a_top + lay_line.i_th (i) * Line_h + 18.0
					w := lay_adv.i_th (i)
					seln := has_selection and i > lo and i <= hi
					if seln then
						set_col (S_rendered)
						ctx.rectangle (x - 1.0, y - 15.0, w + 2.0, 21.0).fill.do_nothing
					elseif b.kind.same_string ("PROSE") then
						if i <= caret then
							tint := W_rendered
						else
							tint := W_dirty
						end
						set_col (tint)
						ctx.rectangle (x - 1.0, y - 15.0, w + 2.0, 21.0).fill.do_nothing
					end
					prose_font (i)
					if seln then
						set_col (C_surface)
					else
						set_col (C_ink)
					end
					txt (x, y, t.substring (i, i))
					i := i + 1
				end
				cxx := Card_x + 22.0 + caret_x
				y := a_top + caret_line * Line_h + 18.0
				set_col (S_failed)
				ctx.rectangle (cxx, y - 16.0, 2.0, 23.0).fill.do_nothing
			else
				draw_plain_wrapped (t, Card_x + 22.0, a_top)
			end
		end

	draw_plain_wrapped (a_text: STRING_32; a_x, a_top: REAL_64)
		local
			n, i, j, k, line: INTEGER
			x, ww: REAL_64
		do
			font (F_text, 13.5, False)
			set_col (C_ink)
			n := a_text.count
			from
				i := 1
				x := 0.0
				line := 0
			until
				i > n
			loop
				if a_text.item (i) = ' ' then
					x := x + adv ({STRING_32} " ")
					i := i + 1
				else
					from
						j := i
					until
						j >= n or else a_text.item (j + 1) = ' '
					loop
						j := j + 1
					end
					ww := 0.0
					from
						k := i
					until
						k > j
					loop
						ww := ww + adv (a_text.substring (k, k))
						k := k + 1
					end
					if x > 0.0 and then x + ww > wrap_w then
						line := line + 1
						x := 0.0
					end
					txt (a_x + x, a_top + line * Line_h + 18.0, a_text.substring (i, j))
					x := x + ww
					i := j + 1
				end
			end
		end

	two_digits (a_n: INTEGER): STRING_32
		do
			create Result.make (2)
			if a_n < 10 then
				Result.append_character ('0')
			end
			Result.append_string_general (a_n.out)
		end

feature {NONE} -- Rendering: right rail

	draw_right_rail
		local
			x, y: REAL_64
		do
			x := Win_w - Right_w + 16.0
			y := Bar_h + 20.0
			y := takes_card (x, y)
			y := parameters_card (x, y + 14.0)
			y := gate_card (x, y + 14.0)
			y := lexicon_card (x, y + 14.0)
		end

	rail_card_w: REAL_64
		do
			Result := Right_w - 36.0
		end

	rail_card (a_x, a_y, a_h: REAL_64; a_title: STRING_32)
		do
			set_col (C_surface)
			fill_rrect (a_x, a_y, rail_card_w, a_h, 3.0)
			set_col (C_outline)
			stroke_rrect (a_x + 0.5, a_y + 0.5, rail_card_w - 1.0, a_h - 1.0, 3.0)
			font (F_mono, 10.0, False)
			set_col (C_ink2)
			txt (a_x + 16.0, a_y + 26.0, a_title)
		end

	takes_card (a_x, a_y: REAL_64): REAL_64
		local
			h, ry: REAL_64
		do
			h := 152.0
			rail_card (a_x, a_y, h, {STRING_32} "TAKES")
			font (F_mono, 10.0, False)
			set_col (C_ink2)
			ry := a_y + 52.0
			txt (a_x + 16.0, ry, {STRING_32} "#   SEED       FID    WPM")
			set_col (W_rendered)
			ctx.rectangle (a_x + 8.0, ry + 8.0, rail_card_w - 16.0, 24.0).fill.do_nothing
			font (F_mono, 11.0, False)
			set_col (C_ink)
			txt (a_x + 16.0, ry + 25.0, {STRING_32} "1   4417822    0.94   142")
			set_col (S_approved)
			txt (a_x + rail_card_w - 38.0, ry + 25.0, {STRING_32} "ok")
			set_col (C_ink)
			txt (a_x + 16.0, ry + 51.0, {STRING_32} "2   9902551    0.91   168")
			txt (a_x + 16.0, ry + 77.0, {STRING_32} "3   1180347    0.94   131")
			Result := a_y + h
		end

	parameters_card (a_x, a_y: REAL_64): REAL_64
		local
			h, sy: REAL_64
		do
			h := 148.0
			rail_card (a_x, a_y, h, {STRING_32} "PARAMETERS")
			font (F_mono, 11.0, False)
			set_col (C_ink2)
			txt (a_x + 16.0, a_y + 52.0, {STRING_32} "exaggeration")
			sy := a_y + 68.0
			set_col (C_outline)
			ctx.rectangle (a_x + 16.0, sy, rail_card_w - 32.0, 4.0).fill.do_nothing
			set_col (S_rendered)
			ctx.rectangle (a_x + 16.0, sy, (rail_card_w - 32.0) * 0.62, 4.0).fill.do_nothing
			ctx.arc (a_x + 16.0 + (rail_card_w - 32.0) * 0.62, sy + 2.0, 7.0, 0.0, 6.2832).fill.do_nothing
			set_col (C_ink2)
			txt (a_x + 16.0, a_y + 104.0, {STRING_32} "seed")
			set_col (C_ink)
			txt (a_x + rail_card_w - 16.0 - adv ({STRING_32} "4417822"), a_y + 104.0, {STRING_32} "4417822")
			font (F_mono, 9.5, False)
			set_col (C_ink2)
			txt (a_x + 16.0, a_y + 128.0, {STRING_32} "changing either re-renders this block")
			Result := a_y + h
		end

	gate_card (a_x, a_y: REAL_64): REAL_64
		local
			h, ry: REAL_64
		do
			h := 236.0
			rail_card (a_x, a_y, h, {STRING_32} "GATE")
			font (F_mono, 26.0, True)
			set_col (C_ink)
			txt (a_x + 16.0, a_y + 62.0, {STRING_32} "0.94")
			font (F_mono, 10.0, False)
			set_col (C_ink2)
			txt (a_x + 16.0, a_y + 82.0, {STRING_32} "round-trip fidelity")
			ry := a_y + 114.0
			gate_row (a_x, ry, {STRING_32} "pace", {STRING_32} "142 wpm")
			gate_row (a_x, ry + 24.0, {STRING_32} "longest run", {STRING_32} "22.4 s")
			gate_row (a_x, ry + 48.0, {STRING_32} "boundary silence", {STRING_32} "410 ms")
			font (F_mono, 10.0, False)
			set_col (S_dirty)
			txt (a_x + 16.0, ry + 82.0, {STRING_32} "60-word sentence")
			txt (a_x + 16.0, ry + 102.0, {STRING_32} "unbroken run over 20 s")
			Result := a_y + h
		end

	gate_row (a_x, a_y: REAL_64; a_label, a_value: STRING_32)
		do
			font (F_mono, 11.0, False)
			set_col (C_ink2)
			txt (a_x + 16.0, a_y, a_label)
			set_col (C_ink)
			txt (a_x + rail_card_w - 16.0 - adv (a_value), a_y, a_value)
		end

	lexicon_card (a_x, a_y: REAL_64): REAL_64
		local
			h: REAL_64
		do
			h := 118.0
			rail_card (a_x, a_y, h, {STRING_32} "LEXICON")
			font (F_mono, 11.0, False)
			set_col (C_ink)
			txt (a_x + 16.0, a_y + 52.0, {STRING_32} "2 unproven: Mesha, Chemosh")
			button (a_x + 16.0, a_y + 68.0, {STRING_32} "Search Respellings", True, True).do_nothing
			Result := a_y + h
		end

	draw_status_bar
		local
			y, x: REAL_64
		do
			y := Win_h - Status_h
			set_col (C_variant)
			ctx.rectangle (0.0, y, Win_w, Status_h).fill.do_nothing
			hline (0.0, y, Win_w)
			font (F_mono, 11.0, False)
			set_col (C_ink2)
			x := 20.0
			txt (x, y + 23.0, {STRING_32} "rendering 3 of 12")
			x := x + adv ({STRING_32} "rendering 3 of 12") + 16.0
			set_col (C_outline)
			ctx.rectangle (x, y + 14.0, 160.0, 8.0).fill.do_nothing
			set_col (S_rendered)
			ctx.rectangle (x, y + 14.0, 40.0, 8.0).fill.do_nothing
			x := x + 176.0
			set_col (C_ink2)
			txt (x, y + 23.0, {STRING_32} "worker alive %/183/ pid 8841     overall 0.87  12 unapproved")
			txt (Win_w - 20.0 - adv ({STRING_32} "saved"), y + 23.0, {STRING_32} "saved")
		end

feature {NONE} -- Drawing helpers

	set_col (a_argb: NATURAL_32)
		do
			ctx.set_color_hex (a_argb.bit_and (0x00FFFFFF)).do_nothing
		end

	font (a_family: STRING_32; a_size: REAL_64; a_bold: BOOLEAN)
		do
			if a_bold then
				ctx.select_font (a_family, ctx.Slant_normal, ctx.Weight_bold).do_nothing
			else
				ctx.select_font (a_family, ctx.Slant_normal, ctx.Weight_normal).do_nothing
			end
			ctx.set_font_size (a_size).do_nothing
		end

	txt (a_x, a_y: REAL_64; a_s: STRING_32)
		do
			ctx.move_to (a_x, a_y).show_text (a_s).do_nothing
		end

	adv (a_s: STRING_32): REAL_64
		do
			Result := ctx.text_extents (a_s).x_advance
		end

	hline (a_x, a_y, a_w: REAL_64)
		do
			set_col (C_outline)
			ctx.rectangle (a_x, a_y, a_w, 1.0).fill.do_nothing
		end

	vline (a_x, a_y, a_h: REAL_64)
		do
			set_col (C_outline)
			ctx.rectangle (a_x, a_y, 1.0, a_h).fill.do_nothing
		end

	rrect_path (a_x, a_y, a_w, a_h, a_r: REAL_64)
		do
			ctx.new_path.do_nothing
			ctx.arc (a_x + a_w - a_r, a_y + a_r, a_r, -1.5708, 0.0).do_nothing
			ctx.arc (a_x + a_w - a_r, a_y + a_h - a_r, a_r, 0.0, 1.5708).do_nothing
			ctx.arc (a_x + a_r, a_y + a_h - a_r, a_r, 1.5708, 3.1416).do_nothing
			ctx.arc (a_x + a_r, a_y + a_r, a_r, 3.1416, 4.7124).do_nothing
			ctx.close_path.do_nothing
		end

	fill_rrect (a_x, a_y, a_w, a_h, a_r: REAL_64)
		do
			rrect_path (a_x, a_y, a_w, a_h, a_r)
			ctx.fill.do_nothing
		end

	stroke_rrect (a_x, a_y, a_w, a_h, a_r: REAL_64)
		do
			rrect_path (a_x, a_y, a_w, a_h, a_r)
			ctx.stroke.do_nothing
		end

	button (a_x, a_y: REAL_64; a_label: STRING_32; a_enabled, a_primary: BOOLEAN): REAL_64
			-- Draw a button; return the x after it.
		local
			w: REAL_64
		do
			font (F_ui, 11.0, False)
			w := adv (a_label) + 22.0
			set_col (C_surface)
			fill_rrect (a_x, a_y, w, 32.0, 3.0)
			if a_primary then
				set_col (S_rendered)
			else
				set_col (C_outline)
			end
			stroke_rrect (a_x + 0.5, a_y + 0.5, w - 1.0, 31.0, 3.0)
			if a_primary then
				set_col (S_rendered)
			elseif a_enabled then
				set_col (C_ink)
			else
				set_col (C_ink2)
			end
			txt (a_x + 11.0, a_y + 21.0, a_label)
			Result := a_x + w
		end

	zone_button (a_x, a_y: REAL_64; a_label: STRING_32; a_enabled, a_primary: BOOLEAN; a_block, a_action: INTEGER): REAL_64
			-- A button with a recorded hit zone bound to a block action.
		local
			r: REAL_64
		do
			r := button (a_x, a_y, a_label, a_enabled, a_primary)
			if a_enabled then
				btn_zones.extend ([a_x, a_y, r - a_x, 32.0, a_block, a_action])
			end
			Result := r
		end

	chip (a_x, a_y: REAL_64; a_label: STRING_32; a_fg, a_bg, a_border: NATURAL_32): REAL_64
			-- Small state chip; returns x after.
		local
			w: REAL_64
		do
			font (F_mono, 9.5, False)
			w := adv (a_label) + 16.0
			set_col (a_bg)
			fill_rrect (a_x, a_y, w, 20.0, 3.0)
			set_col (a_border)
			stroke_rrect (a_x + 0.5, a_y + 0.5, w - 1.0, 19.0, 3.0)
			set_col (a_fg)
			txt (a_x + 8.0, a_y + 14.0, a_label)
			Result := a_x + w
		end

feature {NONE} -- Blit

	blit
		local
			hdc: POINTER
			ws: CAIRO_SURFACE
			c2: CAIRO_CONTEXT
		do
			hdc := c_get_dc
			if hdc /= default_pointer then
				create ws.make_for_dc (hdc)
				if ws.is_valid then
					create c2.make (ws)
					c2.set_source_surface (offscreen, 0.0, 0.0).paint.do_nothing
					c2.destroy
				end
				ws.destroy
				c_release_dc (hdc)
			end
		end

feature {NONE} -- Fonts

	load_fonts
			-- FR_PRIVATE loads: the vendored families become selectable by
			-- name for this process only. Falls back silently per family -
			-- the log records which ones actually arrived.
		local
			dirs: ARRAY [STRING_32]
			d: STRING_32
			i: INTEGER
			f: RAW_FILE
			ok: INTEGER
		do
			dirs := <<
				{STRING_32} "D:\prod\simple_narrate\fonts\",
				{STRING_32} "fonts\">>
			from
				i := dirs.lower
			until
				i > dirs.upper or fonts_loaded
			loop
				d := dirs [i]
				create f.make_with_name (d + {STRING_32} "Archivo.ttf")
				if f.exists then
					ok := add_font (d + {STRING_32} "Archivo.ttf")
						+ add_font (d + {STRING_32} "Literata.ttf")
						+ add_font (d + {STRING_32} "IBMPlexMono.ttf")
					fonts_loaded := ok = 3
					log_line ({STRING_32} "fonts from " + d + {STRING_32} ": " + ok.out + {STRING_32} "/3")
				end
				i := i + 1
			end
			if not fonts_loaded then
				log_line ({STRING_32} "fonts NOT loaded - falling back to system faces")
			end
		end

	add_font (a_path: STRING_32): INTEGER
		local
			s8: STRING_8
			cs: C_STRING
		do
			s8 := a_path.to_string_8
			create cs.make (s8)
			if c_add_font (cs.item) > 0 then
				Result := 1
			end
		end

	fonts_loaded: BOOLEAN

feature {NONE} -- Log

	log_line (a_s: STRING_32)
			-- NEVER print: the runtime allocates a console on first write
			-- in a GUI-subsystem app (the DOS-window gotcha).
		local
			f: PLAIN_TEXT_FILE
		do
			create f.make_with_name ("narrate_session.log")
			if f.exists then
				f.open_append
			else
				f.open_write
			end
			if f.is_open_write then
				f.put_string (a_s.to_string_8)
				f.put_new_line
				f.close
			end
		end

feature {NONE} -- State

	cairo: SIMPLE_CAIRO
	offscreen: CAIRO_SURFACE
	ctx: CAIRO_CONTEXT
	ev_buf: MANAGED_POINTER
	hwnd: POINTER

	blocks: ARRAYED_LIST [NARRATE_BLOCK]

	focused: INTEGER
			-- Index of the block owning caret and selection; 0 = none.

	caret: INTEGER
			-- Insertion position in the focused text, 0 .. count.

	sel_anchor: INTEGER
			-- Other end of the selection; equal to caret when empty.

	dragging: BOOLEAN

	btn_zones: ARRAYED_LIST [TUPLE [x, y, w, h: REAL_64; block, action: INTEGER]]

	text_zones: ARRAYED_LIST [TUPLE [x, y, w, h: REAL_64; block: INTEGER]]

feature {NONE} -- Externals

	c_create_window (a_title: POINTER; a_x, a_y, a_w, a_h: INTEGER): POINTER
		external
			"C inline use %"narrate_win.h%""
		alias
			"return nw_create_window((const wchar_t*)$a_title, (int)$a_x, (int)$a_y, (int)$a_w, (int)$a_h);"
		end

	c_pump: INTEGER
		external
			"C inline use %"narrate_win.h%""
		alias
			"return nw_pump();"
		end

	c_next_event (a_buf: POINTER): INTEGER
		external
			"C inline use %"narrate_win.h%""
		alias
			"return nw_next_event((int*)$a_buf);"
		end

	c_get_dc: POINTER
		external
			"C inline use %"narrate_win.h%""
		alias
			"return nw_get_dc();"
		end

	c_release_dc (a_dc: POINTER)
		external
			"C inline use %"narrate_win.h%""
		alias
			"nw_release_dc($a_dc);"
		end

	c_add_font (a_path: POINTER): INTEGER
		external
			"C inline use %"narrate_win.h%""
		alias
			"return nw_add_font((const char*)$a_path);"
		end

	c_shift_down: INTEGER
		external
			"C inline use %"narrate_win.h%""
		alias
			"return nw_shift_down();"
		end

invariant
	caret_in_range: focused > 0 and focused <= blocks.count implies
		caret >= 0 and caret <= blocks.i_th (focused).text.count
	anchor_in_range: focused > 0 and focused <= blocks.count implies
		sel_anchor >= 0 and sel_anchor <= blocks.i_th (focused).text.count

end
