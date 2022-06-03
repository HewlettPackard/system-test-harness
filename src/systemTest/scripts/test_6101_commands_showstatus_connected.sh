#!/usr/bin/env bash
. $(cd $(dirname $0) ; pwd)/harness/lib_bootstrap.sh || ( echo "ERROR: Cannot bootstrap" ; exit 1 )

test_case_begin "Commands: ShowStatus when connected"
test_case_goal "Check that ShowStatus returns connected status when productA has connection to EMS"
test_case_type "Main functionality"
test_case_when "$HAS_SHOW_STATUS_SUPPORT"

annotate_action "Start simulator that will send an event then call ShowStatus on productA and check that productA is connected to EMS"
run_simulator

test_case_end
