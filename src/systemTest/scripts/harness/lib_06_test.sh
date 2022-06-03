#!/usr/bin/env bash
### Common test routines.
### These routines are used for self documentation, report generation and
### to provide engineer with diagnostic output during test execution.
###
### Example:
### test_case_begin "Unpacking NOM distributable"
### test_case_goal "Check that distributable can be unpacked using way documented for specific target platform"
### test_case_type "Success scenario for main functionality"
### annotate_action "Invoke command with invalid parameters"
### # perform some actions here
### annotate_check "Check that error message is about invalid parameters"
### # perform some checks here
### test_case_end
###

function test_case_begin {
	### Mark start of test case.
	### Usage: test_case_begin <test case name>
	export test_case=$0
	for file in $(ls -1 $bin_dir/begin_test*.sh 2> /dev/null)
	do
		. "$file"
	done;
	current_test="${*:-}"
	mark_as_failed=false
	echo "$(get_time) TEST BEGIN:   $current_test"
}

function test_case_fails_execute {
	### Execute test but mark it as failed in test report
	### Usage: test_case_fails_execute "Fail reason"
	mark_as_failed=true
	local fail_reason="${*:-}"
	echo "$(get_time) Test is marked as failed: $fail_reason. Executing it anyway..."
}

function test_case_fails_skip {
	### Skip test (i. e. do not execute) and mark it as failed in test report
	### Usage: test_case_fails_skip "Fail reason"
	local fail_reason="$*"
	echo "$(get_time) Test is marked as failed: $fail_reason. Skipping..."
	exit 0
}

function test_case_goal {
	### Describe goal of current test case.
	### Usage: test_case_goal <description of test goal>
	echo "$(get_time) TEST GOAL:    ${*:-}"
}

function test_case_type {
	### Describe type of current test case.
	### Examples of types are:
	### Success scenario for main functionality
	### Additional functionality
	### Error handling
	### Usage: test_case_type <type of test case>
	echo "$(get_time) TEST TYPE:    ${*:-}"
}

function test_case_end {
	### Mark end of current test case.
	### Usage: test_case_end
	for file in $(ls -1 $bin_dir/end_test*.sh 2> /dev/null)
	do
		. "$file"
	done;
	if test "${mark_as_failed:-false}" = "true"
	then
		echo "$(get_time) TEST HAS FINISHED BUT IS EXPLICITLY MARKED AS FAILED: $current_test"
	else
		echo "$(get_time) TEST PASSED:  $current_test"
	fi
	mark_as_failed=false
}

function annotate_action {
	### Mark test step action.
	### Usage: annotate_action <action description>
	if test "${verbose:-true}" = "true"
	then
		echo "$(get_time) TEST ACTION:  ${*:-}"
	fi
}

function annotate_check {
	### Mark test step check.
	### Usage: annotate_check <check description>
	echo "$(get_time) TEST CHECK:   ${*:-}"
}

function phase {
	### Mark test phase.
	### Usage: phase <phase name>
	echo "$(get_time) TEST PHASE:   ${*:-}"
}

function test_case_when {
	### Run test only when application supports specified capability.
	### Usage: test_case_when condition
	### Example: test_case_when "$HAS_ADDITIONAL_TEXT_UPDATE && $HAS_PROBABLE_CAUSE_CUSTOMIZATION"
	if ! eval "$1"
	then
		echo "$(get_time) Skipping test because application does not support required functionality..."
		exit 0
	fi
}
