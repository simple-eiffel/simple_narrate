note
	description: "[
		The narrate editor shell - the reference render (docs/_artwork/
		01-editor-window.png) drawn live by simple_cairo through the pure
		Win32 pump, no Vision2. Static composition first: every token,
		type family and layout metric of specs/gui/style_spec.md, painted
		by the same stack that ships simple_ocr_capture 1.8.0.

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
			log_line ({STRING_32} "narrate shell starting")
			load_fonts
			offscreen := cairo.create_surface (Win_w, Win_h)
			create ctx.make (offscreen)
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
						handle_event (ev)
						ev := c_next_event (ev_buf.item)
					end
				end
			end
			log_line ({STRING_32} "session closed")
			ctx.destroy
			offscreen.destroy
		end

	handle_event (a_type: INTEGER)
		do
			if a_type = 6 then
				blit
			end
		end

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

feature {NONE} -- Rendering

	render
		do
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

	draw_map_rail
		local
			states: ARRAY [NATURAL_32]
			i, col, row: INTEGER
			cx, cy, ly: REAL_64
		do
			set_col (C_variant)
			ctx.rectangle (0.0, Bar_h, Rail_w, Win_h - Bar_h - Status_h).fill.do_nothing
			vline (Rail_w - 1.0, Bar_h, Win_h - Bar_h - Status_h)
			font (F_mono, 10.0, False)
			set_col (C_ink2)
			txt (16.0, Bar_h + 26.0, {STRING_32} "MAP")
			states := <<
				S_approved, S_approved, S_approved,
				S_approved, S_rendered, S_dirty,
				S_rendered, S_rendered, S_approved,
				S_approved, S_dirty, S_approved,
				S_approved, S_dirty, S_failed,
				S_rendered, S_approved, S_dirty,
				S_approved, S_approved, S_rendered,
				S_dirty, S_approved, S_approved,
				S_approved, S_rendered, S_dirty,
				S_approved, S_approved, S_approved,
				S_new, S_new, S_new,
				S_new, S_new, S_new>>
			from
				i := states.lower
			until
				i > states.upper
			loop
				col := (i - states.lower) \\ 3
				row := (i - states.lower) // 3
				cx := 16.0 + col * 24.0
				cy := Bar_h + 40.0 + row * 24.0
				set_col (states [i])
				fill_rrect (cx, cy, 18.0, 18.0, 3.0)
				if i = 5 then
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

	legend_row (a_y: REAL_64; a_col: NATURAL_32; a_label: STRING_32)
		do
			set_col (a_col)
			fill_rrect (16.0, a_y, 11.0, 11.0, 2.0)
			font (F_mono, 9.0, False)
			set_col (C_ink2)
			txt (33.0, a_y + 10.0, a_label)
		end

	draw_block_list
		local
			y: REAL_64
		do
			y := Bar_h + 20.0
			y := card_heading (y)
			y := card_dirty (y + 14.0)
			y := card_rendered (y + 14.0)
			y := card_failed (y + 14.0)
		end

	Card_x: REAL_64 = 124.0

	card_w: REAL_64
		do
			Result := Win_w - Right_w - Card_x - 24.0
		end

	card_frame (a_y, a_h: REAL_64; a_stripe: NATURAL_32; a_selected: BOOLEAN)
		do
			set_col (C_surface)
			fill_rrect (Card_x, a_y, card_w, a_h, 3.0)
			if a_selected then
				set_col (S_rendered)
				ctx.set_line_width (2.0).do_nothing
				rrect_path (Card_x - 1.0, a_y - 1.0, card_w + 2.0, a_h + 2.0, 4.0)
				ctx.stroke.do_nothing
				ctx.set_line_width (1.0).do_nothing
			else
				set_col (C_outline)
				stroke_rrect (Card_x + 0.5, a_y + 0.5, card_w - 1.0, a_h - 1.0, 3.0)
			end
			set_col (a_stripe)
			ctx.rectangle (Card_x, a_y + 3.0, 4.0, a_h - 6.0).fill.do_nothing
		end

	head_row (a_y: REAL_64; a_ord: STRING_32; a_kind: STRING_32; a_state: STRING_32; a_fg, a_bg: NATURAL_32; a_fid: STRING_32): REAL_64
			-- Ordinal, kind chip, state chip, fidelity. Returns x after.
		local
			x: REAL_64
		do
			x := Card_x + 22.0
			font (F_mono, 11.0, False)
			set_col (C_ink2)
			txt (x, a_y, a_ord)
			x := x + adv (a_ord) + 12.0
			x := chip (x, a_y - 14.0, a_kind, C_ink2, C_variant, C_outline)
			x := chip (x + 8.0, a_y - 14.0, a_state, a_fg, a_bg, a_fg)
			if not a_fid.is_empty then
				font (F_mono, 11.0, False)
				set_col (C_ink)
				txt (x + 12.0, a_y, a_fid)
				x := x + 12.0 + adv (a_fid)
			end
			Result := x
		end

	card_heading (a_y: REAL_64): REAL_64
		local
			h: REAL_64
			bx: REAL_64
		do
			h := 128.0
			card_frame (a_y, h, S_approved, False)
			head_row (a_y + 30.0, {STRING_32} "07", {STRING_32} "HEADING", {STRING_32} "APPROVED", S_approved, W_approved, {STRING_32} "0.98").do_nothing
			font (F_text, 15.0, False)
			set_col (C_ink)
			txt (Card_x + 22.0, a_y + 66.0, {STRING_32} "The Day Yahweh Looked Defeated")
			bx := Card_x + 20.0
			bx := button (bx, a_y + h - 44.0, {STRING_32} "Play", True, False)
			bx := button (bx + 8.0, a_y + h - 44.0, {STRING_32} "New Take", True, False)
			bx := button (bx + 8.0, a_y + h - 44.0, {STRING_32} "Approved", False, False)
			bx := button (bx + 20.0, a_y + h - 44.0, {STRING_32} "Split Here", False, False)
			bx := button (bx + 8.0, a_y + h - 44.0, {STRING_32} "Up", True, False)
			bx := button (bx + 8.0, a_y + h - 44.0, {STRING_32} "Down", True, False)
			Result := a_y + h
		end

	card_dirty (a_y: REAL_64): REAL_64
		local
			h: REAL_64
			x, bx: REAL_64
		do
			h := 196.0
			card_frame (a_y, h, S_dirty, True)
			x := head_row (a_y + 30.0, {STRING_32} "08", {STRING_32} "PROSE", {STRING_32} "DIRTY", S_dirty, W_dirty, {STRING_32} "")
			font (F_mono, 10.0, False)
			set_col (S_dirty)
			txt (x + 16.0, a_y + 29.0, {STRING_32} "%/8212/  60-word sentence")
			draw_dirty_prose (a_y + 48.0)
			bx := Card_x + 20.0
			bx := button (bx, a_y + h - 44.0, {STRING_32} "Play", False, False)
			bx := button (bx + 8.0, a_y + h - 44.0, {STRING_32} "New Take", True, False)
			bx := button (bx + 8.0, a_y + h - 44.0, {STRING_32} "Approve", False, False)
			bx := button (bx + 20.0, a_y + h - 44.0, {STRING_32} "Split Here", True, True)
			bx := button (bx + 8.0, a_y + h - 44.0, {STRING_32} "Up", True, False)
			bx := button (bx + 8.0, a_y + h - 44.0, {STRING_32} "Down", True, False)
			Result := a_y + h
		end

	draw_dirty_prose (a_top: REAL_64)
			-- The split preview: rendered-tint above the caret, dirty-tint
			-- below, bold runs from the marker syntax, the caret itself in
			-- the failure red - the reference figure's centrepiece.
		local
			words: ARRAY [STRING_32]
			bold_from, bold_to, split_at: INTEGER
			i: INTEGER
			x, y, w, x0: REAL_64
			line_h: REAL_64
			upper: BOOLEAN
			s: STRING_32
		do
			words := <<
				{STRING_32} "And", {STRING_32} "he%/8217/s", {STRING_32} "smart", {STRING_32} "about", {STRING_32} "it,", {STRING_32} "too.",
				{STRING_32} "He", {STRING_32} "doesn%/8217/t", {STRING_32} "overreach.", {STRING_32} "He", {STRING_32} "doesn%/8217/t",
				{STRING_32} "claim", {STRING_32} "the", {STRING_32} "whole", {STRING_32} "Bible", {STRING_32} "is",
				{STRING_32} "one", {STRING_32} "long", {STRING_32} "lie!.",
				{STRING_32} "He", {STRING_32} "does", {STRING_32} "the", {STRING_32} "thing", {STRING_32} "that", {STRING_32} "actually",
				{STRING_32} "works", {STRING_32} "on", {STRING_32} "thoughtful", {STRING_32} "people,", {STRING_32} "which", {STRING_32} "is",
				{STRING_32} "to", {STRING_32} "say:", {STRING_32} "I%/8217/m", {STRING_32} "not", {STRING_32} "asking", {STRING_32} "you",
				{STRING_32} "to", {STRING_32} "distrust", {STRING_32} "the", {STRING_32} "text.", {STRING_32} "I%/8217/m", {STRING_32} "asking",
				{STRING_32} "you", {STRING_32} "to", {STRING_32} "read", {STRING_32} "it", {STRING_32} "more", {STRING_32} "honestly",
				{STRING_32} "than", {STRING_32} "your", {STRING_32} "pastor!", {STRING_32} "does.">>
			bold_from := 17
			bold_to := 19
			split_at := 19
			x0 := Card_x + 22.0
			x := x0
			y := a_top + 20.0
			line_h := 26.0
			upper := True
			from
				i := words.lower
			until
				i > words.upper
			loop
				s := words [i]
				font (F_text, 13.5, (i >= bold_from and i <= bold_to) or s.same_string ({STRING_32} "pastor!"))
				w := adv (s)
				if x + w > Card_x + card_w - 24.0 then
					x := x0
					y := y + line_h
				end
				if upper then
					set_col (W_rendered)
				else
					set_col (W_dirty)
				end
				ctx.rectangle (x - 2.0, y - 16.0, w + 6.0, 22.0).fill.do_nothing
				set_col (C_ink)
				txt (x, y, s)
				x := x + w + 5.0
				if i = split_at then
					set_col (S_failed)
					ctx.rectangle (x - 2.0, y - 17.0, 2.0, 24.0).fill.do_nothing
					upper := False
				end
				i := i + 1
			end
		end

	card_rendered (a_y: REAL_64): REAL_64
		local
			h: REAL_64
			bx: REAL_64
			r: STRING_32
		do
			h := 150.0
			card_frame (a_y, h, S_rendered, False)
			head_row (a_y + 30.0, {STRING_32} "09", {STRING_32} "PROSE", {STRING_32} "RENDERED", S_rendered, W_rendered, {STRING_32} "0.94").do_nothing
			r := {STRING_32} "take 2 rendering"
			font (F_mono, 11.0, False)
			set_col (S_rendered)
			txt (Card_x + card_w - 22.0 - adv (r), a_y + 30.0, r)
			font (F_text, 13.5, False)
			set_col (C_ink)
			txt (Card_x + 22.0, a_y + 66.0, {STRING_32} "He points at the stone, then at 2 Kings 3, then back at the stone, and he lets the")
			txt (Card_x + 22.0, a_y + 88.0, {STRING_32} "two of them argue with each other while he stands off to the side looking reasonable.")
			bx := Card_x + 20.0
			bx := button (bx, a_y + h - 44.0, {STRING_32} "Play", True, False)
			bx := button (bx + 8.0, a_y + h - 44.0, {STRING_32} "New Take", True, False)
			bx := button (bx + 8.0, a_y + h - 44.0, {STRING_32} "Approve", True, True)
			bx := button (bx + 20.0, a_y + h - 44.0, {STRING_32} "Split Here", True, False)
			bx := button (bx + 8.0, a_y + h - 44.0, {STRING_32} "Up", True, False)
			bx := button (bx + 8.0, a_y + h - 44.0, {STRING_32} "Down", True, False)
			Result := a_y + h
		end

	card_failed (a_y: REAL_64): REAL_64
		local
			h: REAL_64
			x, bx: REAL_64
		do
			h := 150.0
			card_frame (a_y, h, S_failed, False)
			x := head_row (a_y + 30.0, {STRING_32} "10", {STRING_32} "SEPARATOR", {STRING_32} "FAILED", S_failed, W_failed, {STRING_32} "")
			font (F_mono, 10.0, False)
			set_col (S_dirty)
			txt (x + 16.0, a_y + 29.0, {STRING_32} "%/8212/  engine: CUDA out of memory")
			font (F_text, 13.5, False)
			set_col (C_ink)
			txt (Card_x + 22.0, a_y + 66.0, {STRING_32} "The Leash %/183/ The Day Yahweh Looked Defeated %/183/ And One Called Mercy")
			bx := Card_x + 20.0
			bx := button (bx, a_y + h - 44.0, {STRING_32} "Retry", True, True)
			bx := button (bx + 8.0, a_y + h - 44.0, {STRING_32} "Play", False, False)
			bx := button (bx + 8.0, a_y + h - 44.0, {STRING_32} "Approve", False, False)
			bx := button (bx + 20.0, a_y + h - 44.0, {STRING_32} "Split Here", True, False)
			bx := button (bx + 8.0, a_y + h - 44.0, {STRING_32} "Up", True, False)
			bx := button (bx + 8.0, a_y + h - 44.0, {STRING_32} "Down", True, False)
			Result := a_y + h
		end

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

end
