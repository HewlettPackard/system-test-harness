#!/usr/bin/env bash

### Functions specific to productB.

### $productB_exploded_kit_dir : A directory where extracted productB kit is located
productB_exploded_kit_dir="$tmp_dir/$PRODUCTB_NAME-$PRODUCTB_VERSION_FULL"

### $productB_log_java : Log for Java part
productB_log_java="/var/opt/Platform/trace/$PRODUCTB_NAME.java.log"

### $productB_log_platform : Log for Platform part
productB_log_platform="/var/opt/Platform/trace/$PRODUCTB_NAME.log"

### $productB_default_trace_mask : Default trace mask
productB_default_trace_mask=1081

### $PRODUCTB_CONF_DIR : Path to directory with configuration files of AM.
PRODUCTB_CONF_DIR="/var/opt/Platform/conf/$PRODUCTB_NAME"

function set_productB_platform_full_trace_for_current_process {
	### Sets ProductB to full logging (only for current process)
	### Usage: set_productB_platform_full_trace_for_current_process
	info "Setting up ProductB debug logging"
	exec_expect_ok "$manage set mcc 0 app $PRODUCTB_NAME process $($manage show mcc 0 app $PRODUCTB_NAME process \* process id | grep "Process Id" | awk '{print $4;}') Trace Mask 0xffffffffffffffff"
}

function set_productB_platform_processing_trace_for_current_process {
	### Sets ProductB to flow tracing (only for current process)
	### Usage: set_productB_platform_processing_trace_for_current_process
	info "Setting up ProductB to flow tracing"
	exec_expect_ok "$manage set mcc 0 app $PRODUCTB_NAME process $($manage show mcc 0 app $PRODUCTB_NAME process \* process id | grep "Process Id" | awk '{print $4;}') Trace Mask $(( $productB_default_trace_mask + 512 ))"
}

function set_productB_platform_production_trace_for_current_process {
	### Sets ProductB to production logging (only for current process)
	### Usage: set_productB_platform_production_trace_for_current_process
	info "Setting up ProductB production logging"
	exec_expect_ok "$manage set mcc 0 app $PRODUCTB_NAME process $($manage show mcc 0 app $PRODUCTB_NAME process \* process id | grep "Process Id" | awk '{print $4;}') Trace Mask $productB_default_trace_mask"
}

function configure_productB_processing_trace_and_restart {
	### Sets ProductB to flow tracing (permanently)
	### Usage: configure_productB_processing_trace_and_restart
	info "Setting up ProductB to flow tracing"
	exec_expect_ok "$manage set mcc 0 app $PRODUCTB_NAME Trace Mask $(( $productB_default_trace_mask + 512 ))"
	as_platform_admin perl -W -pe 's/(logger.transport.*.level)\s*=.*/$1=trace/' -i "/var/opt/Platform/conf/$PRODUCTB_NAME/cst/log4j2.properties"
	as_platform_admin perl -W -pe 's/(logger.rt_.*.level)\s*=.*/$1=trace/' -i "/var/opt/Platform/conf/$PRODUCTB_NAME/cst/log4j2.properties"
	as_platform_admin perl -W -pe 's/(logger.resync_.*.level)\s*=.*/$1=trace/' -i "/var/opt/Platform/conf/$PRODUCTB_NAME/cst/log4j2.properties"
	restart_productB
}

function configure_productB_full_trace_and_restart {
	### Sets ProductB to full tracing (permanently)
	### Usage: configure_productB_full_trace_and_restart
	info "Setting up ProductB to flow tracing"
	exec_expect_ok "$manage set mcc 0 app $PRODUCTB_NAME Trace Mask $(( $productB_default_trace_mask + 512 ))"
	as_platform_admin perl -W -pe 's!level=.*!level=trace!' -i "/var/opt/Platform/conf/$PRODUCTB_NAME/cst/log4j2.properties"
	restart_productB
}

function configure_productB_production_trace_and_restart {
	### Sets ProductB to production logging (permanently)
	### Usage: configure_productB_production_trace_and_restart
	info "Setting up ProductB production logging"
	exec_expect_ok "$manage set mcc 0 app $PRODUCTB_NAME Trace Mask $productB_default_trace_mask"
	as_platform_admin cp -f "$usr_opt_platform/$PRODUCTB_NAME/conf/$PRODUCTB_NAME/cst/log4j2.properties" "/var/opt/Platform/conf/$PRODUCTB_NAME/cst/"
	restart_productB
}

function start_productB {
	### Start productB.
	### Usage: start_productB
	verbose_exec=false exec_expect_ok "$manage start mcc 0 app $PRODUCTB_NAME"
	silent=true check_file_contains_phrases $0.tmp "started"
}

function stop_productB {
	### Stop productB.
	### Usage: stop_productB
	verbose_exec=false exec_expect_ok "$manage stop mcc 0 app $PRODUCTB_NAME"
}

function restart_productB {
	### Restart productB.
	### Usage: restart_productB
	stop_productB
	start_productB
}

function check_productB_installed {
	### Checks that productBs is installed
	### Usage: check_productB_installed
	exec_expect_ok "ls -ld \"$usr_opt_platform/$PRODUCTB_NAME\""
}

function check_productB_activated {
	### Checks that productBs is activated
	### Usage: check_productB_activated
	check_file_exists "/var/opt/Platform/conf/$PRODUCTB_NAME/cst/cst.properties"
}

function find_productB_jvm {
	### Gets the actual JVM used by AM.
	### ProductB must have been running as log is used to understand which JVM is used.
	### Usage: productB_jvm=$(find_productB_jvm)
	tac $productB_log_platform | \
	grep "Loaded Java VM from" | \
	perl -W -pe 's!.*Loaded Java VM from (.*)/(jre/lib|lib/amd64)/.*/libjvm.so.*!$1!' | head -n 1
}

function get_productB_pid {
	### Gets process id of AM.
	### Usage: productB_pid=$(get_productB_pid)
	local jps=$(find_productB_jvm)/bin/jps
	if test ! -x "$jps"
	then
		jps="$(which jps)"
	fi
	as_platform_admin "$jps" -v | grep productB.name=$PRODUCTB_NAME | cut -f 1 -d " "
}
