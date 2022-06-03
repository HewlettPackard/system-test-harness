#!/usr/bin/env bash
. $(cd $(dirname $0) ; pwd)/harness/lib_bootstrap.sh || ( echo "ERROR: Cannot bootstrap" ; exit 1 )

test_case_begin "ProductB kit installation"
test_case_goal "Check that productB kit can be installed"
test_case_type "Main functionality"

phase "Preparation"

annotate_action "Cleanup a directory where productB kit distributable archive will be extracted"
test -d $productB_exploded_kit_dir && rm -r $productB_exploded_kit_dir

annotate_check "Check kit file present"
exec_expect_ok "ls -ld \"$productB_kit_dir/\"*.tar.gz"

annotate_check "Check there is only one kit file"
test $(ls -1 "$productB_kit_dir/"*.tar.gz | wc -l) -eq 1

annotate_check "Check Platform directory present"
check_file_exists "$usr_opt_platform"

phase "Verification"

annotate_action "Unpack ProductB tar archive"
exec_expect_ok "tar zxf \"$productB_kit_dir/\"*.tar.gz -C $(dirname $productB_exploded_kit_dir)"

annotate_action "List content of ProductB tar archive"
exec_expect_ok "ls -alR $productB_exploded_kit_dir"

annotate_action "Install ProductB into Platform non interactively"
exec_expect_ok "$pkgadd -R /usr/opt/Platform -d $productB_exploded_kit_dir -a $productB_exploded_kit_dir/adminFile all"

test_case_end
