#!/usr/bin/env bash
### Functions to handle background processes.
###

### $kill_timeout: time in seconds between SIGTERM and SIGKILL signals are sent to processes
kill_timeout=5

function kill_processes {
	### To all passed processes sends SIGTERM, waits and sends SIGKILL
	### Usage: kill_processes pids
	if test $# -lt 1
	then
		error "Invalid usage: kill_processes pids"
		return 1
	fi
	local pid
	for pid in $1
	do
		killtree $pid
	done
}

function killtree {
	### Politely terminates process and subprocesses.
	### Usage: killtree pid
	### Most probably you need to use kill_pid instead as killtree does not unregister the pid.
	local _pid=$1
	local _child
	for _child in $(UNIX95=true ps -e -o pid,ppid | grep -E "^[[:blank:]]*[[:digit:]]+[[:blank:]]+$_pid$" | awk '{print $1;}')
	do
		echo "Descending to child process $_child of parent $_pid"
		killtree $_child
	done
	terminate_process $_pid
}

function terminate_process {
	### Sends process SIGTERM, waits and sends SIGKILL
	### Usage: [gentle=true] terminate_process pid
	local pid=$1
	if ! ps -p $pid > /dev/null
	then
		echo "Process $pid does not exists"
	else
		if ${gentle:-true}
		then
			echo "Sending TERM to $pid"
			# Ignore exit code because process may happen to exit by itself after we checked
			! as_user_linux root kill $pid
			local waited=0
			while ps -p $pid > /dev/null && test $waited -lt 10
			do
				sleep 1
				waited=$(($waited + 1))
			done
		fi
		if ps -p $pid > /dev/null
		then
			echo "Sending KILL to $pid"
			! as_user_linux root kill -9 $pid
			# Ignore exit code by empty echo command because process may happen to exit by itself after we checked
			true
		fi
	fi
}

function register_pid {
	### Writes passed pid to file for cleanup on error or normal exit
	### Usage: register_pid pid
	if test $# -ne 1
	then
		error "Invalid usage: register_pid pid"
		return 1
	fi
	local pid_dir="$work_dir/pids"
	if ! test -d "$pid_dir"
	then
		mkdir "$pid_dir"
	fi
	echo $1 > "$pid_dir/$1.pid"
}

function wait_pid {
	### Waits for specified registered background process to finish.
	### Automatically unregisters this pid.
	### If timeout is specified and process is still active then this
	### process and all subprocesses are killed and non-zero exit
	### status is returned.
	### Usage: [timeout=Nsec] wait_pid pid
	local pid=$1
	local use_timeout=${timeout:-0}
	info "Waiting for pid $pid to disappear"
	if test $use_timeout -gt 0
	then
		info "Using $use_timeout seconds timeout"
	fi
	local elapsed_time=0
	while ps -p $pid > /dev/null
	do
		if test $use_timeout -gt 0 -a $elapsed_time -gt $use_timeout
		then
			error "Process $pid still exists after $use_timeout seconds. Killing it"
			killtree $pid
			return 1
		fi
		sleep 1
		elapsed_time=$(( elapsed_time + 1 ))
	done
	unregister_pid $pid
}

function unregister_pid {
	### Unregisters previously registered background process.
	### Usage: unregister_pid pid
	local pid=$1
	local pid_dir="$work_dir/pids"
	rm "$pid_dir/$pid.pid" || error_exit "Pid $pid was not registered so cant unregister"
}

function kill_pid {
	### Kills previously registered background process and subprocesses and unregisters it.
	### Usage: kill_pid pid
	### Most probably you need to use kill_registered instead to kill all registered processes.
	local pid=$1
	killtree $pid
	unregister_pid $pid
}

function kill_registered {
	### Kills processes registered with register_pid
	### Usage: kill_registered
	local pid_dir="$work_dir/pids"
	if test -d "$pid_dir"
	then
		local pid_files="$(find "$pid_dir" -name "*.pid")"
		if test -n "$pid_files"
		then
			echo "Killing registered processes"
			kill_processes "$(cat $pid_files)"
			rm $pid_files
		fi
	fi
}
