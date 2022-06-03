#!/usr/bin/env bash
. $(cd $(dirname $0) ; pwd)/harness/lib_bootstrap.sh || ( echo "ERROR: Cannot bootstrap" ; exit 1 )

test_case_begin "Real time events: support for multiple EMS instances"
test_case_goal "Check that productB can receive and process alarms from multiple EMS using same productC"
test_case_type "Main functionality"
test_case_when "$HAS_RAISE"

phase "Preparation"

annotate_action "Prepare 3 operation contexts: first and second collecting from different instances of global class coming from productC and third collecting from instance of default global class of ProductB"
flow_prepare_all

phase "Verification"

annotate_action "Send an alarm from first EMS instance"
(
	export SIM_OPTS="$SIM_OPTS;emsActionListenPort=$emsActionListenPort"
	export SIM_OPTS="$SIM_OPTS;productARtListenPort=$PRODUCTA_LISTEN_PORT_RT_INSTANCE_1"
	run_simulator test_2102_rt_raise_max_fields.groovy
)

annotate_check "Check that first OC collecting alarms from first EMS instance contains an alarm"
wait_for_oc_content $oc_1 'test $count -eq 1'
check_file_contains_phrases $0.tmp "Managed Object = $gc_1 .*:\.$ems_1\b"

annotate_action "Send an alarm from second EMS instance and verify it was received in OC for second EMS instance"
(
	export SIM_OPTS="$SIM_OPTS;emsActionListenPort=$(($emsActionListenPort + 100))"
	export SIM_OPTS="$SIM_OPTS;productARtListenPort=$PRODUCTA_LISTEN_PORT_RT_INSTANCE_2"
	run_simulator test_2102_rt_raise_max_fields.groovy
)

annotate_check "Check that second OC collecting alarms from second EMS instance contains an alarm"
wait_for_oc_content $oc_2 'test $count -eq 1'
check_file_contains_phrases $0.tmp "Managed Object = $gc_1 .*:\.$ems_2\b"

phase "Cleanup"

flow_cleanup_all

test_case_end
