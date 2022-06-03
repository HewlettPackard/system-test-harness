#!/usr/bin/env bash
### Generic functions to wait for a condition.
###

function wait_for_condition {
	### Wait until some condition is true.
	### Usage: [timeout=num_secs] [confidence=0] wait_for_condition 'grep pattern *'
	if test $# -lt 1
	then
		error_exit "wait_for_condition: at least 1 argument expected"
	fi
	local condition="$1"
	local timeout=${timeout:-30}
	local start=$(date +%s)
	info "Waiting $timeout sec for condition: $condition"
	while test $(($timeout + $start)) -gt $(date +%s)
	do
		if ( eval "$condition" > $0_wait.tmp 2>&1 )
		then
			local elapsed=$(( $(date +%s) - $start ))
			local confidence_timeout=${confidence:-$(($elapsed + 1))}
			if test $confidence_timeout -eq 0
			then
				info "Condition $condition matched after $elapsed sec"
				cat $0_wait.tmp
				rm -f $0_wait.tmp
				return 0
			else
				info "Condition $condition matched after $elapsed sec; will be checked again after $confidence_timeout sec"
				sleep $confidence_timeout
				if ( eval "$condition" > $0_wait.tmp 2>&1 )
				then
					info "Condition $condition again matched after $confidence_timeout sec"
					rm -f $0_wait.tmp
					return 0
				else
					break
				fi
			fi
		fi
		sleep 1
	done
	error "Failed to observe condition $condition within $timeout seconds"
	cat $0_wait.tmp
	rm -f $0_wait.tmp
	return 1
}

function wait_for_file_count_in_dir {
	### Waits while specified count of files appears in specified directory.
	### Usage: [timeout=num_secs] [confidence=0] wait_for_file_count_in_dir dir [count]
	### Default value for count is 1
	if test $# -lt 1
	then
		error_exit "wait_for_file_count_in_dir: at least 1 argument expected"
	fi
	local count="${2:-1}"
	local dir="$1"
	local timeout=${timeout:-30}
	local elapsed=0
	info "Waiting $timeout sec for $count files in $dir"
	while test $elapsed -lt $timeout
	do
		if test -d "$dir" -a $(ls -1 "$dir" 2>/dev/null | wc -l) -eq $count
		then
			local confidence_timeout=${confidence:-$elapsed}
			info "Found $count files after $elapsed seconds. Waiting for $confidence_timeout sec if more files will appear."
			sleep $confidence_timeout
			if test $(ls -1 "$dir" | wc -l) -eq $count
			then
				info "Found $count files, wait for them to finish to grow"
				for found_file in $dir/*
				do
					local last_size=$(wc -c "$found_file" | cut -f 1 -d ' ')
					while test $last_size -ne $(wc -c "$found_file" | cut -f 1 -d ' ')
					do
						last_size=$(wc -c "$found_file" | cut -f 1 -d ' ')
						sleep 1
					done
				done
				return 0
			else
				error "Too many files in $dir. Content:"
				ls -1p "$dir"
				return 1
			fi
		else
			if test $(ls -1 "$dir" 2>/dev/null | wc -l) -gt $count
			then
				error "Too many files in $dir. Content:"
				ls -1p "$dir"
				return 1
			fi
		fi
		sleep 1
		elapsed=$(($elapsed + 1))
	done
	error "Too few or too many files were found in $dir within timeout. Content:"
	ls -al "$dir"
	return 1
}
