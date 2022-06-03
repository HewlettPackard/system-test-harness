#!/usr/bin/env bash
. $(cd $(dirname $0) ; pwd)/harness/lib_bootstrap.sh || ( echo "ERROR: Cannot bootstrap" ; exit 1 )

test_case_begin "Downward acknowledgment: acknowledge and unacknowledge"
test_case_goal "Check that productA can acknowledge and unacknowledge an alarm on EMS"
test_case_type "Main functionality"
test_case_when "$HAS_DOWN_ACK"

phase "Preparation"

flow_prepare

phase "Verification"

annotate_action "Run notify domain to collect troubleshooting information"
echo -e "notify domain $default_domain \n spawn sleep 6000" | sudo -i -u  $platform_user $usr_opt_platform/bin/manage &
notify_pid=$!
register_pid $notify_pid

annotate_action "Set productB to flow tracing to collect troubleshooting information"
set_productB_platform_processing_trace_for_current_process

annotate_action "Remember ProductB java log file size"
start_log_size=$(get_file_size "$productB_log_java")

annotate_action "Create backup copy of productB log4j configuration file"
user=$platform_user backup_file "/var/opt/Platform/conf/$PRODUCTB_NAME/cst/log4j2.properties"

annotate_action "Configure productB log4j to trace incoming alarms"
as_platform_admin perl -W -pe 's!logger.transport.level=.*!logger.transport.level=trace!' -i "/var/opt/Platform/conf/$PRODUCTB_NAME/cst/log4j2.properties"
#Uncomment if you need to debug why no traces, otherwise it pollutes test log
#print_file "/var/opt/Platform/conf/$PRODUCTB_NAME/cst/log4j2.properties"
wait_for_condition "tail -c +$start_log_size $productB_log_java | grep \"Tracing was reconfigured\""

annotate_action "Dump productB java log file to collect troubleshooting information"
tail -f -c +$start_log_size "$productB_log_java" &
tail2_pid=$!
register_pid $tail2_pid

annotate_action "Dump productB trace file to collect troubleshooting information"
tail -f -c +$(get_file_size "$productB_log_platform") "$productB_log_platform" &
tail_pid=$!
register_pid $tail_pid

run_simulator

phase "Cleanup"

annotate_action "Restore original productB log4j configuration file"
user=$platform_user restore_file "/var/opt/Platform/conf/$PRODUCTB_NAME/cst/log4j2.properties"

annotate_action "Stop productB java log dumping"
kill_pid $tail2_pid

annotate_action "Stop productB log dumping"
kill_pid $tail_pid

set_productB_platform_production_trace_for_current_process

annotate_action "Stop notify domain"
kill_pid $notify_pid

flow_cleanup

test_case_end
