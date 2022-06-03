#!/usr/bin/env bash

### Functions specific to productA.

### $productA_home : ProductA installation directory.
productA_home="$productA_install_root/$PRODUCTA_NAME-$PRODUCTA_VERSION_FULL"

### $productA_conf : Path to directory with configuration files of productA.
productA_conf="$productA_home/conf"

### $productA_cfg_adv : ProductA advanced configuration directory.
productA_cfg_adv="$productA_conf/adv"

### $productA_cfg_cst : ProductA customization configuration directory.
productA_cfg_cst="$productA_conf/cst"

### $productA_data : ProductA data directory.
productA_data="$productA_home/data"

### $productA_log : ProductA log directory.
productA_log="$productA_data/log"

### $productA_lib : ProductA library directory.
productA_lib="$productA_home/lib"

### $productA_log_file : Log file of productA.
productA_log_file="$productA_log/$PRODUCTA_NAME.log"

function configure_productA_processing_trace {
	### Sets productA to flow tracing (permanently)
	### Usage: configure_productA_processing_trace
	info "Setting up productA to flow tracing"
	backup_file "$productA_home/conf/cst/log4j2.properties"
	perl -W -pe 's/(logger.transport.*.level)\s*=.*/$1=trace/' -i "$productA_home/conf/cst/log4j2.properties"
	perl -W -pe 's/(logger.rt_.*.level)\s*=.*/$1=trace/' -i "$productA_home/conf/cst/log4j2.properties"
	local start_log_size=$(get_file_size "$productA_log_file")
	perl -W -pe 's/(logger.resync_.*.level)\s*=.*/$1=trace/' -i "$productA_home/conf/cst/log4j2.properties"
	confidence=0 wait_for_condition "tail -c +$start_log_size $productA_log_file | grep \"Tracing was reconfigured\""
}

function configure_productA_full_trace {
	### Sets productA to full tracing (permanently)
	### Usage: configure_productA_full_trace
	info "Setting up productA to flow tracing"
	backup_file "$productA_home/conf/cst/log4j2.properties"
	local start_log_size=$(get_file_size "$productA_log_file")
	perl -W -pe 's!level=.*!level=trace!' -i "$productA_home/conf/cst/log4j2.properties"
	confidence=0 wait_for_condition "tail -c +$start_log_size $productA_log_file | grep \"Tracing was reconfigured\""
}

function configure_productA_production_trace {
	### Sets productA to production logging (permanently)
	### Usage: configure_productA_production_trace
	info "Setting up productA production logging"
	local start_log_size=$(get_file_size "$productA_log_file")
	if restore_file "$productA_home/conf/cst/log4j2.properties"
	then
		confidence=0 wait_for_condition "tail -c +$start_log_size $productA_log_file | grep \"Tracing was reconfigured\""
	fi
}

function start_productA {
	### Start productA.
	### Usage: start_productA
	verbose_exec=false exec_expect_ok "$productA_home/bin/start.sh"
}

function stop_productA {
	### Stop productA.
	### Usage: stop_productA
	verbose_exec=false exec_expect_ok "$productA_home/bin/stop.sh"
}

function restart_productA {
	### Restart productA.
	### Usage: restart_productA
	stop_productA
	start_productA
}

function check_productA_installed {
	### Checks that adapters is installed
	### Usage: check_productA_installed
	exec_expect_ok "ls -ld \"$productA_home\""
}

function get_productA_pid {
	### Gets process id of productA.
	### Usage: productA_pid=$(get_productA_pid)
	$JPS -v | grep appName=$PRODUCTA_NAME | cut -f 1 -d " "
}
