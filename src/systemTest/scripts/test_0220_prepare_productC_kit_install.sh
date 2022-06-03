#!/usr/bin/env bash
. $(cd $(dirname $0) ; pwd)/harness/lib_bootstrap.sh || ( echo "ERROR: Cannot bootstrap" ; exit 1 )

test_case_begin "ProductC kit installation"
test_case_goal "Check that productC kit can be installed"
test_case_type "Main functionality"

phase "Preparation"

annotate_action "Cleanup a directory where productC kit distributable archive will be extracted"
test -d $productC_exploded_kit_dir && rm -r $productC_exploded_kit_dir

annotate_check "Check kit file present"
exec_expect_ok "ls -ld \"$productC_kit_dir/\"*.tar.gz"

annotate_check "Check there is only one kit file"
test $(ls -1 "$productC_kit_dir/"*.tar.gz | wc -l) -eq 1

annotate_check "Check Platform directory present"
check_file_exists "$usr_opt_platform"

phase "Verification"

annotate_action "Unpack productC tar archive"
exec_expect_ok "tar zxf \"$productC_kit_dir/\"*.tar.gz -C $(dirname $productC_exploded_kit_dir)"

annotate_action "List content of productC tar archive"
exec_expect_ok "ls -alR $productC_exploded_kit_dir"

annotate_action "Install productC into Platform non interactively"
exec_expect_ok "$pkgadd -R /usr/opt/Platform -d $productC_exploded_kit_dir -a $productC_exploded_kit_dir/adminFile all"

test_case_end
