#!/usr/bin/env bash
. $(cd $(dirname $0) ; pwd)/harness/lib_bootstrap.sh || ( echo "ERROR: Cannot bootstrap" ; exit 1 )

test_case_begin "Commands: ClearStatus"
test_case_goal "Check that ClearStatus command can be sent and processed by productA"
test_case_type "Main functionality"
test_case_when "$HAS_SHOW_STATUS_SUPPORT"

run_simulator

test_case_end
