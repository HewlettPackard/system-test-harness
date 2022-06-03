#!/usr/bin/env bash
### Logging routines.
###

function get_time {
	### Print current time.
	### This function tries to mimic time stamps in log4j log files.
	### Milliseconds are not provided.
	### Usage: echo "$(get_time) Doing something"
	echo "$(date "+%Y-%m-%d %H:%M:%S")"
}

function debug {
	### Print debug message.
	### Message will not be printed if $debug is not set or is not true.
	### Usage:
	### debug [<message>]
	if test "${debug:-false}" = "true"
	then
		echo "$(get_time) TEST DEBUG:   ${*:-}"
	fi
}

function info {
	### Print informational message.
	### Message will not be printed if $verbose is set and is not true.
	### Usage:
	### info [<message>]
	if test "${verbose:-true}" = "true"
	then
		echo "$(get_time) TEST INFO:    ${*:-}"
	fi
}

function error {
	### Print error message.
	### Usage:
	### error [<message>]
	echo "$(get_time) TEST ERROR:   ${*:-}" >&2
}

function error_exit {
	### Print error message and exit with non zero exit code.
	### Usage:
	### error_exit [<message>]
	error "${*:-}"
	return 1
}

function dump_and_exit {
	### Print message that error condition encountered, dump specified file
	### and exit with non zero exit code.
	### This can be used when output from command is redirected into
	### file and test must fail if error happens to also dump
	### command output from file.
	### Usage: some_command > <file> 2>&1 || dump_and_exit <file> [<message>]
	local file_to_dump="$1"
	local message="${2:-Error condition encountered}"
	cat "$file_to_dump"
	error_exit "$message"
}

function warning {
	### Print warning message.
	### Usage:
	### warning [<message>]
	echo "$(get_time) TEST WARNING: ${*:-}"
}

function warn {
	### Print warning message.
	### Usage:
	### warn [<message>]
	warning "${*:-}"
}
