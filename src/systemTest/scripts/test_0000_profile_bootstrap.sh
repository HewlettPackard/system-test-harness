#!/usr/bin/env bash
export TESTS_PROFILE=false
. $(cd $(dirname $0) ; pwd)/harness/lib_bootstrap.sh || ( echo "ERROR: Cannot bootstrap" ; exit 1 )

test_case_begin "Profile test infrastructure"
test_case_goal "Measure what takes time during system tests"
test_case_type "Infrastructure"

test_case_end

print_profile_result
reset_profile_result
