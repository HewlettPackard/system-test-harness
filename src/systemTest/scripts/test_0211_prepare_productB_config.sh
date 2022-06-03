#!/usr/bin/env bash
. $(cd $(dirname $0) ; pwd)/harness/lib_bootstrap.sh || ( echo "ERROR: Cannot bootstrap" ; exit 1 )

test_case_begin "Configure productB connectivity"
test_case_goal "Adjust ProductB connectivity parameters"
test_case_type "Main functionality"

phase "Preparation"

annotate_action "Configure productB: UMB server"
as_platform_admin perl -W -pe "s/^\s*(bootstrap.servers)\s*=\s*CHANGE_ME:(\d+)\s*?\$/\$1=localhost:\$2/" -i $PRODUCTB_CONF_DIR/cst/consumer.properties

print_file $PRODUCTB_CONF_DIR/cst/consumer.properties

annotate_action "Restart productB for the configuration changes to take effect"
restart_productB

test_case_end
