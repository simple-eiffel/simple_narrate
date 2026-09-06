note
	description: "[
		The simple_narrate test runner: every assault, headless, one
		exit code. Prints PASS or FAIL per test; a contract violation
		inside a test is a FAIL, not a crash.
	]"
	author: "Larry Rix"

class
	TEST_APP

create
	make

feature {NONE} -- Initialization

	make
		do
			print ("=== simple_narrate ===%N")
			print ("%N=== THE STUDIO SHELL (Phase S2, step 1) ===%N")
			run_shell_tests

			print ("%N========================%N")
			print ("Results: " + passed.out + " passed, " + failed.out + " failed%N")
			if failed > 0 then
				print ("TESTS FAILED%N")
			else
				print ("ALL TESTS PASSED%N")
			end
		end

feature {NONE} -- Batteries

	shell_tests: STUDIO_SHELL_ASSAULT

	run_shell_tests
		do
			create shell_tests
			run_test (agent shell_tests.test_the_shell_opens_shaped_with_every_zone_empty, "the_shell_opens_shaped_with_every_zone_empty (offscreen)")
			run_test (agent shell_tests.test_a_hebrew_title_reads_right_to_left, "a_hebrew_title_reads_right_to_left (offscreen PNG)")
			run_test (agent shell_tests.test_the_menus_offer_only_what_exists, "the_menus_offer_only_what_exists")
			run_test (agent shell_tests.test_the_theme_faces_are_loaded, "the_theme_faces_are_loaded")
			run_test (agent shell_tests.test_the_frame_wears_the_style_spec_tokens, "the_frame_wears_the_style_spec_tokens")
		end

feature {NONE} -- Running

	run_test (a_test: PROCEDURE; a_name: STRING)
			-- Run one test; any exception (contract or otherwise) fails it.
		local
			l_retried: BOOLEAN
		do
			if not l_retried then
				a_test.call (Void)
				print ("  PASS: " + a_name + "%N")
				passed := passed + 1
			end
		rescue
			print ("  FAIL: " + a_name + "%N")
			failed := failed + 1
			l_retried := True
			retry
		end

	passed: INTEGER

	failed: INTEGER

end
