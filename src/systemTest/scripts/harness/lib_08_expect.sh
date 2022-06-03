#!/usr/bin/env bash
### Poor man's implementation of expect
###

function wait_for_input_prompt {
	### Wait for expected input prompt in a file.
	### Usage: [timeout=num_sec] wait_for_input_prompt prompt [file]
	### Example:
	### 	test -f $0.tmp && rm $0.tmp
	### 	(wait_for_input_prompt "Your choice:" && echo 1) > interactive_command | tee $0.tmp
	local file="${2:-$0.tmp}"
	local prompt="$1"
	local timeout="${timeout:-60}"
	local elapsed=0
	while test $timeout -gt $elapsed
	do
		if tail -n 1 "$file" | grep -q -P -e "$prompt"
		then
			return 0
		fi
		sleep 1
		elapsed=$(( $elapsed + 1 ))
	done
	error "Failed to observe prompt \"$prompt\" within $timeout seconds in \"$file\""
	return 1
}
