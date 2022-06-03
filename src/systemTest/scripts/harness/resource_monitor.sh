#!/usr/bin/env bash
### Monitors resource usage and plots graph
###     Usage:
###         To start
###             $harness_dir/resource_monitor.sh record reporting_period_sec > data_file &
###             monitor_pid=$!
###             register_pid $monitor_pid
###         To stop
###             kill_pid $monitor_pid
###         To plot graph using gnuplot
###             $harness_dir/resource_monitor.sh plot data_file

function get_cpu_load {
	if test "$(uname -s)" = Linux
	then
		echo $(( 100 - $(top -b -n 2 -d 0.5 | grep -i 'cpu(s)' | tail -n 1 | awk '{print $5}' | cut -d . -f 1 ) ))
	else
		echo $(( 100 - $( top -d 1 -h -f top.output.tmp ; cat top.output.tmp | head -n 6 | tail -n 1 | awk '{print $5}' | cut -d . -f 1 ; rm top.output.tmp < /dev/null ) ))
	fi
}

mode=$1

case $mode in
record)
	reporting_period=$2
	echo "#Total CPU load %"
	while true
	do
		get_cpu_load
		sleep $reporting_period
	done
;;
plot)
	datafile=$2
	if gnuplot --version
	then
		echo "set terminal png ; set output \"$datafile.png\" ; set ylabel 'Total CPU usage %' ; set xlabel 'Time' ; unset xtics ; plot \"$datafile\" with lines title \"$(basename $datafile)\"" | gnuplot
	else
		echo "Cant plot graph because dont have gnuplot"
	fi
;;
esac
