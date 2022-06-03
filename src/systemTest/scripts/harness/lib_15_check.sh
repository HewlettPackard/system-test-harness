#!/usr/bin/env bash
### Generic common check functions.
###

function check_file_contains_phrases {
	### Check that file with command output contains phrases that match specified Perl regexp
	### Usage: [silent=false] [quiet=false] [in_loop=false] [from=byte] check_file_contains_phrases FILE PERL_REGEXP1 [PERL_REGEXP2 ...]
	### Does not prints anything when in_loop or quiet.
	if test $# -lt 2
	then
		error_exit "check_file_contains_phrases: >= 2 arguments expected"
	fi
	local file_name="$1"
	check_file_exists "$file_name"
	shift
	if ${quiet:-false} || ${in_loop:-false} || ${silent:-false}
	then
		local be_silent=true
	else
		local be_silent=false
	fi
	if ! $be_silent
	then
		info "Checking in $file_name (from byte ${from:-0}) for phrases: $@"
	fi
	local foundLines=""
	for phrase in "$@"
	do
		local foundLine="$(! tail -c +${from:-0} "$file_name" | grep -m 1 -i -P -e "$phrase")"
		if test -n "$foundLines"
		then
			foundLines="$foundLines
$foundLine"
		else
			foundLines="$foundLine"
		fi
		if test -z "$foundLine"
		then
			if ! $be_silent
			then
				from=${from:-0} print_file "$file_name"
				error "Phrase \"$phrase\" not found in $file_name (from byte ${from:-0})"
			fi
			return 1
		fi
	done
	if ! $be_silent
	then
		info "Found:"
		echo "$foundLines" | awk '!x[$0]++'
	fi
	return 0
}

function check_file_does_not_contain_phrases {
	### Check that file with command output does not contain perl regexp.
	### Usage: [quiet=false] [in_loop=false] [from=byte] check_file_does_not_contain_phrases FILE PERL_REGEXP1 [PERL_REGEXP2 ...]
	### Does not prints anything when in_loop or quiet.
	if test $# -lt 2
	then
		error_exit "check_file_does_not_contain_phrases: >= 2 arguments expected"
	fi
	local file_name="$1"
	check_file_exists "$file_name"
	shift
	if ${quiet:-false} || ${in_loop:-false}
	then
		local be_silent=true
	else
		local be_silent=false
	fi
	if ! $be_silent
	then
		info "Checking in $file_name (from byte ${from:-0}) for absence of phrases: $@"
	fi
	for phrase in "$@"
	do
		if tail -c +${from:-0} "$file_name" | grep -iP -e "$phrase"
		then
			if ! $be_silent
			then
				from=${from:-0} print_file "$file_name"
				error "Phrase \"$phrase\" found in $file_name (from byte ${from:-0})"
			fi
			return 1
		fi
	done
	return 0
}

function check_file_contains_phrase_count {
	### Checks that phrase occurs in file specified amount of times.
	### Usage: [quiet=false] [in_loop=false] check_file_contains_phrase_count phrase amount [file]
	### Does not prints anything when in_loop or quiet.
	### If file is not specified then $0.tmp is used by default.
	test $# -eq 2 -o $# -eq 3 || error_exit "check_file_contains_phrase_count: invalid number of arguments"
	local phrase="$1"
	local amount="$2"
	if test $# -eq 3
	then
		local file="$3"
	else
		local file="$0.tmp"
	fi
	if ${quiet:-false} || ${in_loop:-false}
	then
		local be_silent=true
	else
		local be_silent=false
	fi
	if ! $be_silent
	then
		info "Checking that \"$phrase\" occurs $amount times in $file"
	fi
	local occurrences=$(get_phrase_count_in_file "$phrase" "$file")
	if test $occurrences -ne $amount
	then
		if ! $be_silent
		then
			print_file "$file"
			error "Phrase \"$phrase\" occurs $occurrences times instead of $amount in $file"
		fi
		return 1
	fi
	return 0
}

function check_file_exists {
	### Checks if file exists
	### Usage: [quiet=false] [in_loop=false] check_file_exists FILE
	### Does not prints anything when in_loop or quiet.
	if ! test $# -eq 1
	then
		error_exit "check_file_exists: 1 argument expected"
	fi
	local file_name="$1"
	if ${quiet:-false} || ${in_loop:-false}
	then
		local be_silent=true
	else
		local be_silent=false
	fi
	if test -z "$file_name" || test ! -e "$file_name"
	then
		if ! $be_silent
		then
			error "File does not exist: $file_name"
		fi
		return 1
	fi
	return 0
}

function check_file_does_not_exist {
	### Checks if file does not exist
	### Usage: [quiet=false] [in_loop=false] check_file_does_not_exist FILE
	### Does not prints anything when in_loop or quiet.
	if ! test $# -eq 1
	then
		error_exit "check_file_does_not_exist: 1 argument expected"
	fi
	local file_name="$1"
	if ${quiet:-false} || ${in_loop:-false}
	then
		local be_silent=true
	else
		local be_silent=false
	fi
	if test -e "$file_name"
	then
		if ! $be_silent
		then
			error "File exists: $file_name"
		fi
		return 1
	fi
}

function check_dir_not_exist_or_empty {
	### Checks that specified directory does not exist or is empty
	### Usage: [quiet=false] [in_loop=false] check_dir_not_exist_or_empty dir
	### Does not prints anything when in_loop or quiet.
	local dir=$1
	if ${quiet:-false} || ${in_loop:-false}
	then
		local be_silent=true
	else
		local be_silent=false
	fi
	if test -d "$dir"
	then
		if ! $be_silent
		then
			info "Checking if directory is empty: $dir"
		fi
		if test $(ls -A $dir | wc -l) -ne 0
		then
			if ! $be_silent
			then
				error "Directory is not empty: $dir"
				ls -A $dir
			fi
			return 1
		fi
	else
		if ! $be_silent
		then
			info "Directory does not exist: $dir"
		fi
	fi
	return 0
}

function check_file_contains_one_string_all_phrases {
	### Check that file contains only one string with all specified perl regexp.
	### Usage: [quiet=false] [in_loop=false] check_file_contains_one_string_all_phrases FILE PERL_REGEXP1 [PERL_REGEXP2 ...]
	### Does not prints anything when in_loop or quiet.
	if test $# -lt 2
	then
		error_exit "check_file_contains_one_string: >= 2 arguments expected"
	fi
	local file_name="$1"
	check_file_exists "$file_name"
	shift
	if ${quiet:-false} || ${in_loop:-false}
	then
		local be_silent=true
	else
		local be_silent=false
	fi
	if ! $be_silent
	then
		info "Checking for a single line with all phrases in $file_name: $@"
	fi
	local command="cat $file_name"
	for phrase in "$@"
	do
		command="$command | grep -iP -e '$phrase'"
	done
	if ! eval "$command"
	then
		if ! $be_silent
		then
			print_file $file_name
			error "There is no line that contains all phrases in $file_name: $@"
		fi
		return 1
	fi
	return 0
}

function check_exactly_one_file_in_dir {
	### Checking that there is one and only one file in directory
	### Usage: [quiet=false] [in_loop=false] check_exactly_one_file_in_dir directory_name
	### Does not prints anything when in_loop or quiet.
	test $# -eq 1 || error_exit "Invalid number of arguments"
	local dir="$1"
	if ${quiet:-false} || ${in_loop:-false}
	then
		local be_silent=true
	else
		local be_silent=false
	fi
	if ! $be_silent
	then
		info "Checking that there is one and only one file in directory: $dir"
	fi
	if test $(ls -1 $dir | wc -l) -ne 1
	then
		if ! $be_silent
		then
			error "Directory does not contain exactly one file: $dir"
			ls -A $dir
		fi
		return 1
	fi
	return 0
}

function check_dir_is_empty {
	### Checks that directory is empty
	### Usage: [quiet=false] [in_loop=false] check_dir_is_empty directory_name
	### Does not prints anything when in_loop or quiet.
	test $# -eq 1 || error_exit "Invalid number of arguments"
	local dir="$1"
	if ${quiet:-false} || ${in_loop:-false}
	then
		local be_silent=true
	else
		local be_silent=false
	fi
	if ! $be_silent
	then
		info "Checking that directory is empty: $dir"
	fi
	if test $(ls -1 $dir | wc -l) -ne 0
	then
		if ! $be_silent
		then
			error "Directory is not empty: $dir"
			ls -A $dir
		fi
		return 1
	fi
	return 0
}

function check_dir_is_not_empty {
	### Checks that directory is not empty
	### Usage: [quiet=false] [in_loop=false] check_dir_is_not_empty directory_name
	### Does not prints anything when in_loop or quiet.
	test $# -eq 1 || error_exit "Invalid number of arguments"
	local dir="$1"
	if ${quiet:-false} || ${in_loop:-false}
	then
		local be_silent=true
	else
		local be_silent=false
	fi
	if ! $be_silent
	then
		info "Checking that directory is not empty: $dir"
	fi
	if test $(ls -1 $dir | wc -l) -eq 0
	then
		if ! $be_silent
		then
			error "Directory is empty: $dir"
			ls -A $dir
		fi
		return 1
	fi
	return 0
}

function check_exist_file_with_phrase_in_dir_by_mask {
	### Checks if there is a file with given pattern name and content in a directory.
	### Handles large number of files when file name pattern would expand in too long line.
	### Outputs names of found files.
	### Usage: [quiet=false] [in_loop=false] check_exist_file_with_phrase_in_dir_by_mask file_content_pattern directory_name file_name_pattern
	### Does not prints anything when in_loop or quiet.
	local phrase="$1"
	local dir="$2"
	local mask="$3"
	if ${quiet:-false} || ${in_loop:-false}
	then
		local be_silent=true
	else
		local be_silent=false
	fi
	if ! $be_silent
	then
		info "Checking for presence of file matching $mask in directory $dir that contains phrase $phrase"
	fi
	if ! ( test -d "$dir" && find "$dir" -type f -name "$mask" -exec grep -m 1 -o -H -P -e "$phrase" {} \; | grep -E "[[:alnum:]]" )
	then
		if ! $be_silent
		then
			error "Directory $dir does not contain file with name $mask that contains phrase $phrase"
			ls -A $dir
		fi
		return 1
	fi
	return 0
}

function check_user_root {
	### Check that current user is root.
	### Usage: [quiet=false] [in_loop=false] check_user_root
	### Does not prints anything when in_loop or quiet.
	if ${quiet:-false} || ${in_loop:-false}
	then
		local be_silent=true
	else
		local be_silent=false
	fi
	if test "$(whoami)" != "root"
	then
		if ! $be_silent
		then
			error "Current use is not root: $(whoami)"
		fi
		return 1
	fi
	return 0
}

function check_log_file_for_problems {
	### Looks through the specified file starting
	### from specified position for specified message pattern.
	### When found, tries to filter out messages that should be ignored if pattern_to_ignore is set.
	### If after filtering messages set is not empty,
	### prints what was left and exits with non zero code.
	### Usage:
	### [quiet=false] [in_loop=false] check_log_file_for_problems <file> <staring_position> <log_entry_regexp_mask> <pattern_to_find> [<pattern_to_ignore>]
	### pattern_to_find does not support multilined patterns
	### pattern_to_ignore supports multilined patterns, as '.' matches any symbol including '\n'
	### You have to escape any / as \/
	### Does not prints anything when in_loop or quiet.
	if test $# -lt 4
	then
		error_exit "Incorrect number of arguments"
	fi
	local log_file="$1"
	local log_starting_pos=$2
	local log_entry_regexp_mask=$3
	local pattern_to_find=$4
	local pattern_to_ignore=${5:-something_that_no_one_ever_put_in_log_file}
	if ${quiet:-false} || ${in_loop:-false}
	then
		local be_silent=true
	else
		local be_silent=false
	fi
	if test -f "$log_file"
	then
		if $(tail -c +$log_starting_pos "$log_file" | grep -Pq -e "$pattern_to_find")
		then
			local found_problems_lines=$(tail -c +$log_starting_pos "$log_file" | perl -W -ne 'if(/'"$pattern_to_find"'/g){print "$.\n";}')
			local ignored_problems_lines=$(tail -c +$log_starting_pos "$log_file" | perl -W -0777 -pe 's/('"$pattern_to_ignore"')/entry_is_ignored_by_hook:$1/sg' | perl -W -ne 'if(/entry_is_ignored_by_hook/g){print "$.\n";}')
			for line in $found_problems_lines
			do
				local log_entry_line=$line
				while test -z "$(tail -c +$log_starting_pos "$log_file" | head -n $log_entry_line | tail -n 1 | perl -W -ne 'print if(/'"$log_entry_regexp_mask"'/g)')"
				do
					local log_entry_line=`expr $log_entry_line - 1`
				done
				local log_entries_lines_for_found_problems+="$log_entry_line\n"
			done
			for line in $ignored_problems_lines
			do
				local log_entry_line=$line
				while test -z  "$(tail -c +$log_starting_pos "$log_file" | head -n $log_entry_line | tail -n 1 | perl -W -ne 'print if(/'"$log_entry_regexp_mask"'/g)')"
				do
					local log_entry_line=`expr $log_entry_line - 1`
				done
				local log_entries_lines_for_ignored_problems+="$log_entry_line\n"
			done
			if test -z "$ignored_problems_lines"
			then
				local unexpected_problem_lines=$(printf "$log_entries_lines_for_found_problems")
			else
				local uniq_problem_lines=$(printf "$log_entries_lines_for_found_problems$log_entries_lines_for_ignored_problems" | sort | uniq -u | xargs -i printf "%d\n" {})
				local unexpected_problem_lines=$(printf "$log_entries_lines_for_found_problems$uniq_problem_lines" | sort | uniq -d)
			fi
			if ! test -z "$unexpected_problem_lines"
			then
				if ! $be_silent
				then
					error "Unexpected problems were detected in log file: $log_file"
					echo "============================================================="
					for line in $unexpected_problem_lines
					do
						tail -c +$log_starting_pos "$log_file" | head -n $(expr $line + 19) | tail -n 20
						echo "----------------------------------------"
					done
					echo "============================================================="
				fi
				return 1
			fi
		fi
	fi
	return 0
}

function check_permissions {
	### Checks permissions of the specified directory and files located there.
	### Usage:
	### [quiet=false] [in_loop=false] check_permissions <dir> <expected directory permissions (in symbolic form)> <expected files permissions (in symbolic form)>
	### Does not prints anything when in_loop or quiet.
	local dir="$1"
	local expected_dir_mode="$2"
	local expected_file_mode="$3"
	if test $# -lt 3
	then
		error_exit "Incorrect number of arguments"
	fi
	if ${quiet:-false} || ${in_loop:-false}
	then
		local be_silent=true
	else
		local be_silent=false
	fi
	local actual_dir_mode="$(ls -ld "$dir" | awk '{print $1}' | cut -c 2-10)"
	if test "$actual_dir_mode" != "$expected_dir_mode"
	then
		if ! $be_silent
		then
			error "Expected directory mode is $expected_dir_mode but was $actual_dir_mode for $dir"
		fi
		return 1
	fi
	find "$dir" -maxdepth 1 -type f -printf "%pUNIQUE_FIELD_SEPARATOR%M \n" | \
	while read line
	do
		local actual_file_mode="$(echo "$line" | awk -F 'UNIQUE_FIELD_SEPARATOR' '{print $2}' | cut -c 2-10)"
		local file="$(echo "$line" | awk -F 'UNIQUE_FIELD_SEPARATOR' '{print $1}')"
		if test "$actual_file_mode" != "$expected_file_mode"
		then
			if ! $be_silent
			then
				error "Expected file mode is $expected_file_mode but was $actual_file_mode for $file"
			fi
			return 1
		fi
	done
	return 0
}

function check_permissions_single {
	### Checks permissions of the specified file or directory.
	### if directory is specified, it does not check content of the directory.
	### Usage:
	### [quiet=false] [in_loop=false] check_permissions_single <dir_or_file> <expected permissions (in symbolic form)>
	### Does not prints anything when in_loop or quiet.
	local file_or_dir="$1"
	local expected_mode="$2"
	if test $# -lt 2
	then
		error_exit "Incorrect number of arguments"
	fi
	if ${quiet:-false} || ${in_loop:-false}
	then
		local be_silent=true
	else
		local be_silent=false
	fi
	local actual_mode="$(ls -ld "$file_or_dir" | awk '{print $1}' | cut -c 2-10)"
	if test "$actual_mode" != "$expected_mode"
	then
		if ! $be_silent
		then
			error "Expected file/directory mode is $expected_mode but was $actual_mode for $file_or_dir"
		fi
		return 1
	fi
	return 0
}

function check_ownership {
	### Checks that files and directories in the specified path has specified ownership.
	### Usage:
	### [quiet=false] [in_loop=false] check_ownership <dir> <expected owner>
	### Does not prints anything when in_loop or quiet.
	local path="$1"
	local expected_ownership="$2"
	if test $# -lt 2
	then
		error_exit "Incorrect number of arguments"
	fi
	if ${quiet:-false} || ${in_loop:-false}
	then
		local be_silent=true
	else
		local be_silent=false
	fi
	find "$path" -printf "%pUNIQUE_FIELD_SEPARATOR%u \n" | \
	while read line
	do
		local actual_ownership="$(echo "$line" | awk -F 'UNIQUE_FIELD_SEPARATOR' '{print $2}')"
		local dir_or_file="$(echo "$line" | awk -F 'UNIQUE_FIELD_SEPARATOR' '{print $1}')"
		if test "$actual_ownership" != "$expected_ownership"
		then
			if ! $be_silent
			then
				error "Expected file/directory ownership is $expected_ownership but was $actual_ownership for $dir_or_file"
			fi
			return 1
		fi
	done
	return 0
}
