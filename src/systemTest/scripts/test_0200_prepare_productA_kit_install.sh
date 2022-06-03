#!/usr/bin/env bash
. $(cd $(dirname $0) ; pwd)/harness/lib_bootstrap.sh || ( echo "ERROR: Cannot bootstrap" ; exit 1 )

test_case_begin "ProductA kit installation"
test_case_goal "Check that productA kit can be installed"
test_case_type "Main functionality"

phase "Preparation"

annotate_check "Check kit file present"
exec_expect_ok "ls -ld \"$productA_kit_dir/\"*.tar.gz"

annotate_check "Check there is only one kit file"
test $(ls -1 "$productA_kit_dir/"*.tar.gz | wc -l) -eq 1

phase "Verification"

annotate_action "Unpack productA tar archive"
exec_expect_ok "tar zxf $productA_kit_dir/*.tar.gz -C $productA_install_root"

annotate_action "List content of productA tar archive"
exec_expect_ok "ls -alR $productA_install_root"

test_case_end
