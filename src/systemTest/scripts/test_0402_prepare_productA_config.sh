#!/usr/bin/env bash
. $(cd $(dirname $0) ; pwd)/harness/lib_bootstrap.sh || ( echo "ERROR: Cannot bootstrap" ; exit 1 )

test_case_begin "Configure productA connectivity"
test_case_goal "Adjust productA connectivity parameters"
test_case_type "Main functionality"

phase "Preparation"

annotate_action "Configure productA: network host where to send resync requests to EMS"
perl -W -pe "s/^\s*(emsActionListenHost)\s*=\s*CHANGE_ME\s*?\$/\$1=localhost/" -i $productA_conf/cst/cst.properties

annotate_action "Configure productA: network port where to send resync requests to EMS"
perl -W -pe "s/^\s*(emsActionListenPort)\s*=\s*CHANGE_ME\s*?\$/\$1=$emsActionListenPort/" -i $productA_conf/cst/cst.properties

print_file $productA_conf/cst/cst.properties

annotate_action "Configure productA: UMB server"
perl -W -pe "s/^\s*(bootstrap.servers)\s*=\s*CHANGE_ME:(\d+)\s*?\$/\$1=localhost:\$2/" -i $productA_conf/cst/producer.properties

print_file $productA_conf/cst/producer.properties

test_case_end
