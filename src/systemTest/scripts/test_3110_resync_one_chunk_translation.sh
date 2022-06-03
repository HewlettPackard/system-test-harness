#!/usr/bin/env bash
. $(cd $(dirname $0) ; pwd)/harness/lib_bootstrap.sh || ( echo "ERROR: Cannot bootstrap" ; exit 1 )

test_case_begin "Resynchronization: translation"
test_case_goal "Check that productB correctly translates alarms during resynchronization"
test_case_type "Main functionality"
test_case_when "$HAS_RESYNC"

phase "Preparation"

flow_prepare

phase "Verification"

run_simulator

phase "Cleanup"

flow_cleanup

test_case_end
