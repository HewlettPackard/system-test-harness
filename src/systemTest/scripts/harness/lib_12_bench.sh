#!/usr/bin/env bash

### A library that adds benchmarking capabilities.
### Usage:
###   bench_start
###   something
###   duration=$(bench_duration)

function bench_start {
	### Starts measurement.
	### Exports global variable with timestamp when measurement was started.
	### Usage: bench_start
	bench_start_timestamp=$(date +%s)
}

function bench_duration {
	### Returns duration elapsed from last bench_start.
	### Returns an error if bench_start wasn't started yet or bench_duration was
	### already executed for last bench_start call.
	### Duration resolution is seconds.
	if test -z "${bench_start_timestamp:-}"
	then
		error "No pair call to bench_start"
		return 1
	fi
	echo $(( $(date +%s) - $bench_start_timestamp ))
	bench_start_timestamp=""
}

function get_epoch_milli {
	### Returns number of milliseconds that have passed since start of the epoch.
	### Usage: start_ms=$(get_epoch_milli)
	echo $(($(date +%s%N) / 1000000))
}
