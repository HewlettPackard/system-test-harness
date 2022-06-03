#!/usr/bin/env bash

. $(cd $(dirname $0) ; pwd)/harness/lib_bootstrap.sh || ( echo "ERROR: Cannot bootstrap" ; exit 1 )

test_case_begin "ProductA kit removal"
test_case_goal "Check that productA kit can be removed"
test_case_type "Main functionality"

phase "Preparation"

annotate_check "Check productA is installed"
check_productA_installed

phase "Verification"

annotate_action "Stop productA"
stop_productA

annotate_action "Store productA log files for tests results analysis"
mkdir -pv $work_dir/productA_logs/
find $productA_home -name "*.log" -exec cp -v '{}' $work_dir/productA_logs/ ';'

annotate_action "Remove productA installation directory"
exec_expect_ok "rm -r $productA_home < /dev/null"

test_case_end
