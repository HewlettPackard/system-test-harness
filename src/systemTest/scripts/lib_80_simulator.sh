#!/usr/bin/env bash

###
### Support functions for work with Groovy based per test case simulator.
###

function run_simulator {
	### Runs simulator and waits until it exits.
	### Usage: exec_expect_ok "[SIM_BASE_CP=$BUILD_DIR/libs/simulator/*] run_simulator [script] [param1 [param2 [...]]]"
	### By default, script is the same as test script name but with .sh replaced with .groovy.
	### If script doesn't end with .groovy then it is considered to be a script parameter instead.
	### Script is supposed to be in $bin_dir.
	### Groovy and other dependencies are supposed to be in BUILD_DIR/libs/simulator/.
	### Java is taken from $JAVA variable.
	### You can add an extra classpath directory using simulator_cp_extra variable.
	### This variable is evaluated dynamically so you can escape dollar within it and it
	### will be evaluated correctly at run time.
	### You can pass additional java options using SIM_JAVA_OPTS environment variable.
	local script="$(basename "$0" .sh).groovy"
	local caller="$0"
	if echo "${1:-}" | grep -q ".groovy"
	then
		script="$1"
		shift
	fi
	local cp="${SIM_BASE_CP:-$BUILD_DIR/libs/simulator/*}"
	if test -n "${simulator_cp_extra:-}"
	then
		cp="$cp:$(eval "echo $simulator_cp_extra")"
	fi
	(
		eval export $(declare -p|perl -W -ne 'if($_=~/^declare\s--\s([a-zA-Z][\w\d_]+)=/){print $1." "}')
		eval export -f $(declare -F|perl -W -ne 'if($_=~/^declare\s-f\s([a-zA-Z][\w\d_]+)/){print $1." "}')
		$JAVA -cp "$cp" "-D0=$caller" ${SIM_JAVA_OPTS:-} groovy.lang.GroovyShell "$bin_dir/$script" "$@"
	)
}
