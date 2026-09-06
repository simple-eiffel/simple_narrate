note
	description: "[
		The `narrate' executable: one STUDIO_SHELL, shown and pumped
		until it closes. Nothing else lives here - the shell is built
		and asserted headless by STUDIO_SHELL_ASSAULT, and this root
		only gives it a desktop.
	]"
	author: "Larry Rix"

class
	STUDIO_APP

create
	make

feature {NONE} -- Initialization

	make
			-- Open the Studio.
		local
			l_shell: STUDIO_SHELL
		do
			create l_shell.make (Window_x, Window_y, Window_width, Window_height)
			l_shell.run
		end

feature -- Constants

	Window_x: INTEGER = 120
	Window_y: INTEGER = 80
	Window_width: INTEGER = 1500
	Window_height: INTEGER = 960

end
