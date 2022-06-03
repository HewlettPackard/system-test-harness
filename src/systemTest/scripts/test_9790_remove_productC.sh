#!/usr/bin/env bash
. $(cd $(dirname $0) ; pwd)/harness/lib_bootstrap.sh || ( echo "ERROR: Cannot bootstrap" ; exit 1 )

test_case_begin "ProductC kit removal"
test_case_goal "Check that productC kit can be removed"
test_case_type "Main functionality"

phase "Verification"

annotate_action "Remove productC distributable files before executing pkgrm"
exec_expect_ok "rm -r $productC_exploded_kit_dir"

annotate_action "Remove productC from Platform non interactively without adminFile"
# pkgrm manual - https://docs.oracle.com/cd/E19253-01/816-5166/6mbb1kqcn/index.html
exec_expect_ok "yes | $pkgrm -R /usr/opt/Platform $PRODUCTC_PACKAGE_NAME"

annotate_action "Perform steps from installation guide: Remove: Remove productC configuration directory"
exec_expect_ok "as_platform_admin rm -r /var/opt/Platform/conf/$PRODUCTC_NAME < /dev/null"

test_case_end
