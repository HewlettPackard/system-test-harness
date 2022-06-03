#!/usr/bin/env bash
### Functions related to process/command execution.
###

function exec_expect_ok {
	### Invoke command, expect zero exit code and redirect stdout/stderr to file
	### Usage: exec_expect_ok command [output_file]
	### If not specified then $0.tmp is used by default
	### If $verbose_exec is set to false then output will not be printed if there is no error
	test $# -eq 1 -o $# -eq 2 || error_exit "Invalid number of arguments"
	local command="$1"
	if test $# -eq 2
	then
		local output_file="$2"
	else
		local output_file="$0.tmp"
	fi
	info "Executing $command"
	eval "$command" > "$output_file" 2>&1 || dump_and_exit "$output_file" "Zero exit code expected but was non-zero"
	if test ${verbose_exec:-true} = true
	then
		cat "$output_file"
		echo
	else
		true
	fi
}

function exec_expect_error {
	### Invoke command, check non-zero exit code and output to tmp file
	### Usage: exec_expect_error command [output_file]
	### If not specified then $0.tmp is used by default
	test $# -eq 1 -o $# -eq 2 || error_exit "Invalid number of arguments"
	local command="$1"
	if test $# -eq 2
	then
		local output_file="$2"
	else
		local output_file="$0.tmp"
	fi
	info "Executing $command"
	annotate_check "Check that exit code is not zero"
	eval "$command" > "$output_file" 2>&1 \
	&& dump_and_exit "$output_file" "Non zero exit code expected"
	cat "$output_file"
}

function as_user_linux {
	### Runs specified command with provided arguments
	### as specified user and in current directory.
	### Usage: [environment_white_list="JAVA_HOME|^LC_.+"] as_user_linux user command [param1 ["p a r a m 2"]]
	if test $# -lt 2
	then
		error_exit "Incorrect number of arguments"
	fi
	local user=$1
	shift
	if test $arch != L
	then
		error_exit "as_user_linux is supported only on Linux"
	else
		local script=$(mktemp -u -p $tmp_dir).sh
		local environment_white_list="${environment_white_list:-JAVA_HOME|^LC_.+}"
		env | grep -E -e "$environment_white_list" | perl -W -pe "s/'/'\\\''/g;s/(.+?)=(.*)/export \$1='\$2'/g" > $script
		echo "cd \"$PWD\"" >> $script
		while test $# -gt 0
		do
			echo '' "'$1' " | tr -d '\n' >> $script
			shift
		done
		printf "\n" >> $script
		chmod +x $script
		if sudo -i -u $user $script "$@"
		then
			local exit_code=0
		else
			local exit_code=1
			error "Failed to run command as user $user. The script was:"
			cat $script 1>&2
		fi
		rm $script < /dev/null
		return $exit_code
	fi
}
