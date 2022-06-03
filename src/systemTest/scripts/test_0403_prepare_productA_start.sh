#!/usr/bin/env bash
. $(cd $(dirname $0) ; pwd)/harness/lib_bootstrap.sh || ( echo "ERROR: Cannot bootstrap" ; exit 1 )

test_case_begin "Start productA"
test_case_goal "Start productA"
test_case_type "Main functionality"

phase "Preparation"

annotate_action "Start productA"
start_productA

test_case_end
