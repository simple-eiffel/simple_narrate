note
	description: "[
		One block of the narration session - the demo model behind the
		shell. Kind and state are the closed vocabularies of the spec;
		text carries the !marker! emphasis syntax inline.
	]"

class
	NARRATE_BLOCK

create
	make

feature {NONE} -- Initialization

	make (a_ordinal: INTEGER; a_kind, a_state, a_fid, a_warn, a_text: STRING_32)
		require
			ordinal_positive: a_ordinal > 0
			kind_known: is_valid_kind (a_kind)
			state_known: is_valid_state (a_state)
		do
			ordinal := a_ordinal
			kind := a_kind
			state := a_state
			fid := a_fid
			warn := a_warn
			text := a_text
		ensure
			ordinal_set: ordinal = a_ordinal
			text_set: text = a_text
		end

feature -- Access

	ordinal: INTEGER

	kind: STRING_32
			-- HEADING | PROSE | SEPARATOR

	state: STRING_32
			-- APPROVED | RENDERED | DIRTY | FAILED | NEW

	fid: STRING_32
			-- Fidelity figure as shown, empty when none.

	warn: STRING_32
			-- Warning summary, empty when none.

	text: STRING_32

feature -- Status

	is_valid_kind (a_k: READABLE_STRING_32): BOOLEAN
		do
			Result := a_k.same_string ("HEADING")
				or a_k.same_string ("PROSE")
				or a_k.same_string ("SEPARATOR")
		end

	is_valid_state (a_s: READABLE_STRING_32): BOOLEAN
		do
			Result := a_s.same_string ("APPROVED")
				or a_s.same_string ("RENDERED")
				or a_s.same_string ("DIRTY")
				or a_s.same_string ("FAILED")
				or a_s.same_string ("NEW")
		end

feature -- Element change

	set_ordinal (a_n: INTEGER)
		require
			positive: a_n > 0
		do
			ordinal := a_n
		ensure
			set: ordinal = a_n
		end

	set_state (a_s: STRING_32)
		require
			known: is_valid_state (a_s)
		do
			state := a_s
		ensure
			set: state = a_s
		end

	set_text (a_t: STRING_32)
		do
			text := a_t
		ensure
			set: text = a_t
		end

	mark_dirty
			-- An edit invalidates any render: the state semantics of the
			-- spec, in one place.
		do
			if not state.same_string ("FAILED") then
				set_state ({STRING_32} "DIRTY")
			end
		end

invariant
	text_attached: text /= Void
	kind_valid: is_valid_kind (kind)
	state_valid: is_valid_state (state)

end
