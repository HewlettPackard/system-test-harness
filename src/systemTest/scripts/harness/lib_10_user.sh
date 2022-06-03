#!/usr/bin/env bash
### Automatically switches user if not run via CI.
###     If there is at least one definition of required user for any of the test sets
###     and this configuration was already loaded (as it should have been)
###     then current user will be checked to be the desired user
###     and test will be automatically restarted under required user if needed,
###     Desired user is determined via run_tests.sh --show-user CURRENT_TEST_NAME

if declare -p | grep -q -P "declare -- cfg_filter_user_[^=]+="
then
	if ! $ci && echo "$(basename "$0")" | grep -qE "^test_[[:digit:]]+.*\.sh$"
	then
		if desired_user="$($harness_dir/run_tests.sh --show-user "$(basename "$0")")"
		then
			if test -n "$desired_user" -a "$desired_user" != "$(whoami)"
			then
				script="$(basename "$0")"
				echo ")))----- restarting $script as $desired_user -----((("
				cd $bin_dir ; sudo -u $desired_user -E -n ./$script
				exit $?
			fi
		fi
	fi
fi
