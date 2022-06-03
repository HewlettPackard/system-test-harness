#!/usr/bin/env bash
. $(cd $(dirname $0) ; pwd)/harness/lib_bootstrap.sh || ( echo "ERROR: Cannot bootstrap" ; exit 1 )

test_case_begin "Real time events translation: maximum fields"
test_case_goal "Check that productB can translate and forward events with typical set of fields provided by EMS"
test_case_type "Main functionality"
test_case_when "$HAS_RAISE"

phase "Preparation"

flow_prepare

phase "Verification"

run_simulator

phase "Cleanup"

flow_cleanup

test_case_end
