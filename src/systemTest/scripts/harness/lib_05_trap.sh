#!/usr/bin/env bash
### Setups traps to handle errors and perform cleanups.
###

function get_proc_trace {
	### Gets backtrace for current process (parent processes).
	### Usage: backtrace="$(get_proc_trace)"
	local trace=""
	local currentPid=$$
	while true
	do
		local cmdline
		local parentPid
		cmdline=$(tr \\0 ' ' < /proc/$currentPid/cmdline)
		parentPid=$(grep PPid /proc/$currentPid/status | awk '{ print $2 }')
		trace="$trace [$currentPid]:$cmdline\n"
		if test "$currentPid" == "1"
		then
			break
		fi
		currentPid=$parentPid
	done
	echo -en "$trace"
}

function get_stack {
	### Gets backtrace for current shell.
	### Usage: backtrace="$(get_stack)"
	local stack=""
	local stack_size=${#FUNCNAME[@]}
	for i in $(seq 1 $((stack_size-1)))
	do
		local func="${FUNCNAME[$i]}"
		if test x$func = x
		then
			func=MAIN
		fi
		local linen="${BASH_LINENO[$(( i - 1 ))]}"
		local src="${BASH_SOURCE[$i]}"
		if test x"$src" = x
		then
			src=non_file_source
		fi
		stack+=$'\n'"   at: "$func" "$src" "$linen
	done
	echo -en "$stack"
}

function execute_cleanup_hooks {
	### Executes all cleanup hook scripts
	### Usage: execute_cleanup_hooks
	# find cleanup hooks scripts in $bin_dir directory and execute them in alphabetical order
	local hook_scripts=$(ls -1 $bin_dir | grep -E "^hook_.{1,}\.sh$")
	local who
	local sudo_cmd
	if test -n "${hook_user:-}"
	then
		who=$hook_user
	else
		who=$(whoami)
	fi
	if test -n "$hook_scripts"
	then
		sleep 1
		printf "$(date "+%Y-%m-%d %H:%M:%S") TEST WARN:    Executing hooks as user $who:"
		for hook in $hook_scripts
		do
			printf " $hook "
			sudo -E -u $who bash -c "cd $bin_dir ; do_traps=false ; . $bin_dir/harness/lib_bootstrap.sh ; disable_traps ; set +o errexit ; set +o nounset ; exec 1>$work_dir/${hook}_$who.out.txt ; exec 2>&1 ; . $bin_dir/$hook" < /dev/null
		done
		printf "\n"
	fi
}

function on_exit {
	### Handles exit.
	set +o errexit
	kill_registered
	execute_cleanup_hooks
}

function disable_traps {
	### Disables traps on EXIT
	### Usage: disable_traps
	trap - ERR
	trap - EXIT
}

function enable_traps {
	### Enables traps on EXIT
	### Usage: enable_traps
	trap 'code=$? ; trap - ERR ; trap - EXIT ; echo -e "\n$(date "+%Y-%m-%d %H:%M:%S") TEST ERROR:   Failed with code $code in $0:$LINENO" ; on_exit ; exit $code' ERR
	trap 'code=$? ; trap - ERR ; trap - EXIT ; test $code -ne 0 && echo -e "\n$(date "+%Y-%m-%d %H:%M:%S") TEST ERROR:   Exiting with non-zero code $code in $0:$LINENO" ; on_exit ; exit $code' EXIT
}

if test "${do_traps:-false}" = "true"
then
	enable_traps
fi
