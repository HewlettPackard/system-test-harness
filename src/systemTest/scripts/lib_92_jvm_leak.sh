#!/usr/bin/env bash

### A library to check ProductB JVM for memory leaks.

function dump_productB_heap {
	### Dumps ProductB heap statistics.
	### Usage: dump_productB_heap index
	local jmap=$(find_productB_jvm)/bin/jmap
	if test ! -x "$jmap"
	then
		jmap="$(which jmap)"
	fi
	as_platform_admin "$jmap" -histo:live $(get_productB_pid) | \
	grep -P "\s*\d+:\s+\d+\s+\d+\w+" | \
	perl -W -pe 's/^\s*\d+:\s+(\d+)\s+\d+\s+(.+)\s*$/$2\t$1\n/' \
	> $0.heap.$(printf %02d $1).tmp
}

function check_productB_heap_for_leaks {
	### Run a trend check on heap dumps generated by dump_productB_heap.
	### Usage: check_productB_heap_for_leaks [ignore_patterens_list]
	### ignore_patterens_list - is a comma separated list of regexp patterns for class names
	### to be ignored during heap dump analysis.
	run_simulator lib_92_jvm_leak.groovy "$(dirname "$0")" "$(basename "$0.heap.")" "$@"
}

function clean_productB_dumps {
	### Deletes dumps generated by dump_productB_heap.
	### Usage: clean_productB_dumps
	rm -vf $0.heap.*.tmp
}
