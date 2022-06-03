#!/usr/bin/env bash
. $(cd $(dirname $0) ; pwd)/harness/lib_bootstrap.sh || ( echo "ERROR: Cannot bootstrap" ; exit 1 )

test_case_begin "ProductB kit removal"
test_case_goal "Check that productB kit can be removed"
test_case_type "Main functionality"

phase "Preparation"
annotate_check "Check productB is installed"
check_productB_installed

phase "Verification"

annotate_action "Remove productB distributable files before executing pkgrm"
exec_expect_ok "rm -r $productB_exploded_kit_dir"

annotate_action "Remove productB from Platform non interactively without adminFile"
# pkgrm manual - https://docs.oracle.com/cd/E19253-01/816-5166/6mbb1kqcn/index.html
exec_expect_ok "yes | $pkgrm -R /usr/opt/Platform $PRODUCTB_PACKAGE_NAME"

annotate_action "Perform steps from installation guide: Remove: Remove productB advanced configuration and customization directories"
exec_expect_ok "as_platform_admin rm -r /var/opt/Platform/conf/$PRODUCTB_NAME < /dev/null"

annotate_action "Store ProductB trace files for tests results analysis"
if test -f /var/opt/Platform/trace/$PRODUCTB_NAME.log
then
	exec_expect_ok "cp -v /var/opt/Platform/trace/$PRODUCTB_NAME*.log* $work_dir"
fi

annotate_action "Perform steps from installation guide: Remove: Remove productB trace files"
if test -f /var/opt/Platform/trace/$PRODUCTB_NAME.log
then
	exec_expect_ok "as_platform_admin rm -r /var/opt/Platform/trace/$PRODUCTB_NAME*.log* < /dev/null"
fi

annotate_action "Perform steps from installation guide: Remove: Remove productB data directory"
exec_expect_error "as_platform_admin rm -r /var/opt/Platform/$PRODUCTB_NAME < /dev/null"

test_case_end
