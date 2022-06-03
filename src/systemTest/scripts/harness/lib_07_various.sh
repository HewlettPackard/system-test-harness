#!/usr/bin/env bash
### Assorted heap of various things.
###

function get_file_size {
	### Get file size in bytes.
	### Usage: size=$(get_file_size file)
	if test $# -ne 1
	then
		error_exit "get_file_size: 1 argument expected"
	fi
	test -f "$1" || touch "$1"
	wc -c "$1" | cut -d ' ' -f 1
}

function get_phrase_count_in_file {
	### Get them number of phrase occurrences in file.
	### Usage: get_phrase_count_in_file phrase [file]
	### If file is not specified then $0.tmp is used by default
	test $# -eq 1 -o $# -eq 2 || error_exit "get_phrase_count_in_file: invalid number of arguments"
	local phrase="$1"
	if test $# -eq 2
	then
		local file="$2"
	else
		local file="$0.tmp"
	fi
	local regex=$(echo $phrase | perl -W -pe 's/\//\\\//g')
	cat "$file" | perl -pe "s/($regex)/\$1\n/g" | grep -iP -e "$phrase" | wc -l
}

function find_one_file_containing_all_phrases {
	### Find in the specified directory the only file that contain all of specified phrases
	### Usage: find_one_file_containing_all_phrases directory phrase1 [phrase2 ...]
	### If more than one file with all specified phrases exist in the directory, then exit with error
	if test $# -lt 2
	then
		error_exit "find_one_file_containing_all_phrases: >= 2 arguments expected"
	fi
	local dir=$1
	if test ! -d $dir
	then
		error_exit "$dir - directory does not exist"
	fi
	shift
	local found_file=""
	for file in $dir/*
	do
		local command="cat $file"
		for phrase in "$@"
		do
			command="$command | grep -iP -e '$phrase'"
		done
		command="$command >/dev/null"
		if eval $command
		then
			if test -z "$found_file"
			then
				found_file="$file"
			else
				error_exit "Found more than one file with specified phrases in directory $dir"
			fi
		fi
	done
	echo $found_file
}

function atomic_copy {
	### (Pseudo)atomically copies file to polled directory in a way
	### that ensures that polling process sees whole file but not partial content.
	### Usage: atomic_copy source target
	local source="$1"
	local target="$2"
	info "Atomically copying $source to $target"

	case $target in
	*/)
		debug "Treat target as directory"
		test -d $target || error_exit "Target directory not found: $target"
	;;
	*.xml)
		debug "Treat target as file"
		test -d $(dirname $target) || error_exit "Directory for target file not found: $target"
	;;
	*)
		debug "Treat target as directory"
		test -d $target || error_exit "Target directory not found: $target"
	;;
	esac

	local target_parent="$(dirname $(dirname "$target"))"
	local tmp_file="$target_parent/$(basename "$source")"
	cp "$source" "$tmp_file"
	mv "$tmp_file" "$target"
}

function print_file {
	### Print file contents on stdout in eye-friendly manner
	### Usage: [from=byte] print_file activemq.xml
	if ! test $# -eq 1
	then
		error_exit "1 argument expected"
	fi
	local f="$1"
	echo
	echo "File $f (from byte ${from:-0}):"
	echo "==================================================================="
	tail -c "+${from:-0}" "$f"
	echo
	echo "==================================================================="
	echo
}

function get_performance_result_file_name {
	### Gets the name of the file where performance test results should be written to.
	### Usage: echo "10 event per sec" > $(get_performance_result_file_name)
	echo "$0.result.txt"
}

function print_performance_test_results {
	### Implements common formatting of performance tests
	### Usage: format_performance_test_results amount_of_messages time rate [type]
	if ! test $# -eq 3 -o $# -eq 4
	then
		error_exit "3 or 4 arguments expected"
	fi
	local out=$(get_performance_result_file_name)
	if test $# -eq 4
	then
		printf "Type: $4; " >> "$out"
	fi
	echo "Amount of messages: $1; Time: $2 s; Rate: $3 messages per second" >> "$out"
	cat "$out"
}

function clean_dir {
	### Cleans specified directory. Does not cause error if directory does not exist yet.
	### Usage: clean_dir dir_name
	local dir=$(dirname "$1")/$(basename "$1")
	if test -d "$dir"
	then
		if test "$(ls -1 "$dir" | wc -l)" -gt 0
		then
			info "Cleaning $dir"
			find "$dir" -depth | grep -v -E "^$dir\$" | xargs -i rm -r "{}"
			test -d "$dir" || error_exit "deleted $dir again!!!"
		else
			info "Directory $dir is already empty"
		fi
	else
		info "Directory $dir does not exist"
	fi
	return 0
}

function sleep_short {
	### Sleep for short period of time
	### Usage: sleep_short
	info "Sleeping for short time"
	sleep 10
}

function sleep_long {
	### Sleep for long period of time
	### Usage: sleep_long
	info "Sleeping for long time"
	sleep 30
}

function sum_numbers {
	### Calculate sum of numbers.
	### Argument: set of numbers delimited with space or new-line symbol
	### Usage: sum_numbers 1 2 3 4 5
	local sum=0
	for n in $*
	do
		sum=$(($sum+$n))
	done
	echo $sum
}
