#!/usr/bin/env bash
### Functions to work with JMeter.
###

function extract_performance_data_from_jmeter {
	### Get amount of samples, time taken and sample rate from
	### JMeter's Generate Summary Results.
	### Usage:
	###     jmeter > report
	###     perf_data=$(extract_performance_data_from_jmeter report)
	###     echo $perf_data
	###     Result: 524288 388s 1350.3
	local input_file=$1
	annotate_action "Record performance metrics from JMeter"
	grep "Generate Summary Results =" $input_file | tail -n 1 | perl -W -pe 's!.*Generate\s+Summary Results\s+=\s+(\d+)\s+in\s+([\d.\w]+)\s+=\s+([\d.]+).*!$1 $2 $3!'
}

function check_jmeter_summary_no_errors {
	### Check if Jmeter output contains signs of errors.
	### Requires "Generate Summary Results" listener to be used in test plan with default parameters.
	### $0.tmp that is default output file used by exec_expect_ok is used as input file.
	### General usage pattern is:
	### exec_expect_ok "$jmeter params"
	### check_jmeter_summary_no_errors [jmeter stdout file]
	local in_file="${1:-$0.tmp}"
	annotate_check "Check JMeter recorded no errors"
	info "Checking Jmeter output file $in_file"
	if ! grep 'Generate Summary Results =' "$in_file"
	then
		cat "$in_file"
		error_exit "Cant find summary results"
	fi
	local errors_number=$(($(cat "$in_file" | grep 'Generate Summary Results =' | tail -n 1 | cut -d : -f 5 | awk '{print $1}' | tr -d "\r" | tr "\n" +)0))
	if test $errors_number -eq 0
	then
		info "No errors found in JMeter summary"
	else
		error_exit "$errors_number errors found in Jmeter summary"
	fi
}

function handle_jmeter_summary {
	### Analyze, reformat and output results based on JMeter summary output
	### Usage: handle_jmeter_summary jmeter_output_file threshold
	if test ! $# -eq 2
	then
		error_exit "2 arguments expected"
	fi
	local jmeter_output_file="$1"
	local threshold="$2"

	# Check if there are errors. If so, then report and exit.
	if grep -E "[[:space:]]+Err:[[:space:]]+[1-9]" $jmeter_output_file
	then
		error_exit "Errors found in Jmeter summary"
	fi

	# Process strings like "Acknowledge summary = ..."
	grep -E "[[:alpha:]]+[[:space:]]+summary[[:space:]]+=" $jmeter_output_file |\
	while read string
	do
		local group_amount_time_rate="$(echo $string | perl -W -pe 's|^(\w+)\s+summary\s+=\s+([\d\.]+)\s+in\s+([\d\.]+)s\s+=\s+([\d\.\*]+)/s.*|$1 $2 $3 $4|g')"
		local group=$(echo "$group_amount_time_rate" | awk '{print $1}')
		local amount=$(echo "$group_amount_time_rate" | awk '{print $2}')
		local time=$(echo "$group_amount_time_rate" | awk '{print $3}')
		local rate=$(echo "$group_amount_time_rate" | awk '{print $4}')
		if echo "$rate" | grep -q  "*"
		then
			error_exit "Group $group: JMeter failed to measure message rate. Check JMeter output for errors."
		fi
		print_performance_test_results $amount $time $rate $group
		if test ${rate%[[:punct:]]*} -lt $threshold
		then
			error_exit "Group $group: message rate $rate is below $threshold messages per second"
		fi
	done
}
