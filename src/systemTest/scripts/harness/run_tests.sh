#!/usr/bin/env bash
### Run all or group of tests.

### To disable cleanup on exit set do_traps environment variable to false:
###     do_traps=false harness/run_tests.sh
### To run specific test that requires preparation or resume testing from some point
### use something like the following:
###     do_traps=false harness/run_tests.sh --prepare && harness/run_tests.sh --from 3500
do_traps=${do_traps:-true}
. $(cd $(dirname $0) ; pwd)/lib_bootstrap.sh || ( echo "ERROR: Cannot bootstrap" ; exit 1 )

cd "$bin_dir"

print_error_and_exit() {
	echo "$1"
	exit 1
}

need_root=false
function require_root {
	need_root=true
}

from=''
stop_before=''
dry=false
show_filter=false

include_filter="$cfg_filter_include_default"
exclude_filter="$cfg_filter_exclude_default"
user_filter=""

while test $# -gt 0
do
	option="$1"
	shift
	case "$option" in
	"--skip")
		### --skip <pattern>
		###     Skip tests matching specified pattern
		if test $# -lt 1; then
			disable_traps
			print_error_and_exit "ERROR: Agrument expected"
		fi
		if test -n "$exclude_filter"
		then
			exclude_filter="$exclude_filter|$1"
		else
			exclude_filter="$1"
		fi
		shift
	;;
	"--stop-before")
		### --stop-before <test number>
		###     Stop running tests before specified one.
		###     Traps are automatically disabled.
		if test $# -lt 1; then
			disable_traps
			print_error_and_exit "ERROR: Agrument expected"
		fi
		disable_traps
		stop_before=$1
		shift
	;;
	"--from")
		### --from <test number>
		###     Skip tests before specified one
		if test $# -lt 1; then
			disable_traps
			print_error_and_exit "ERROR: Agrument expected"
		fi
		from=$1
		shift
	;;
	"--dry")
		### --dry
		###     Print tests names but dont run anything
		dry=true
		disable_traps
	;;
	"--show-filter")
		### --show-filter
		###     Shows list of tests to be run in shell friendly format.
		###     Nothing gets actually run.
		show_filter=true
		disable_traps
	;;
	"--list")
		### --list
		###     Shows all available test filters
		start_profile "$0 --list"
		for filter_name in $(grep -E "^[[:space:]]*cfg_filter_include_[_[:alnum:]]+[[:space:]]*=" ./cfg_tests.sh | cut -d _ -f 4- | cut -d = -f 1)
		do
			echo --$filter_name
		done
		disable_traps
		register_profile_result "$0 --list"
		exit 0
	;;
	"--help")
		### --help
		###     Shows usage information
		grep "###" $0 | grep -v 'grep "###"' | cut -d "#" -f 4-
		disable_traps
		exit 0
	;;
	"--show-user")
		### --show-user test_name_pattern
		###     Show user under which to run specified test
		if test $# -lt 1; then
			disable_traps
			print_error_and_exit "ERROR: Agrument expected"
		fi
		pattern="$1"
		disable_traps
		start_profile "$0 --show-user"
		if declare -p | grep -q -P "declare -- cfg_filter_user_[^=]+="
		then
			users=""
			for testset in $($0 --list | grep -v default)
			do
				user="$($0 --dry "$testset" | perl -ne "if(m/Running test case [^\\s]*$pattern[^\\s]* as ([^\\s\\n]+)/){ printf \"\$1\\n\"; }")"
				users="$(echo -e "$users\n$user"|sort -u|sed '/^$/d')"
			done
			if test "$(echo -e "$users" | wc -l)" -ne 1
			then
				print_error_and_exit "ERROR: Multiple users found or no user configured for $pattern: $(echo $users)"
			else
				echo $users
			fi
		fi
		register_profile_result "$0 --show-user"
		exit 0
	;;
	*)
		### --<filter name>
		###     Run tests defined by specified filter.
		###     Filters should be specified in cfg_tests.sh.
		###     See description of cfg_tests.sh for filters details.
		start_profile "$0 parse test set definition"
		option="${option#--}"
		if printf "$option" | grep -q -
		then
			disable_traps
			print_error_and_exit "ERROR: Invalid option $option"
		fi
		export testset=${testset:-$option}
		include_filter_name=cfg_filter_include_$option
		exclude_filter_name=cfg_filter_exclude_$option
		flags_filter_name=cfg_filter_flags_$option
		user_filter_name=cfg_filter_user_$option
		include_filter_value="$(eval echo \${$include_filter_name:-nosuchvar})"
		exclude_filter_value="$(eval echo \${$exclude_filter_name:-nosuchvar})"
		flags_filter_value="$(eval echo \${$flags_filter_name:-nosuchvar})"
		user_filter_value="$(eval echo \${$user_filter_name:-nosuchvar})"
		if test "$include_filter_value" = nosuchvar -a "$exclude_filter_value" = nosuchvar
		then
			disable_traps
			print_error_and_exit "ERROR: Invalid option $option"
		fi
		if test "$include_filter_value" != nosuchvar
		then
			include_filter="$include_filter_value"
		fi
		if test "$exclude_filter_value" != nosuchvar
		then
			exclude_filter="$exclude_filter_value"
		fi
		if test "$flags_filter_value" != nosuchvar
		then
			eval "$flags_filter_value"
		fi
		if test "$user_filter_value" != nosuchvar
		then
			user_filter="$user_filter_value"
		fi
		register_profile_result "$0 parse test set definition"
	;;
	esac
done

test_start=$(perl -e 'print time;')

if test -n "$from"
then
	skip=true
else
	skip=false
fi

filter_to_report=""

for test_case in $(ls -1 | grep -E "^test_[[:digit:]]{4}_.{1,}\.sh$" | grep -E "$include_filter" | grep -E -v "$exclude_filter" | sort -n -k 2 -t _)
do
	if $skip && test -n "$from" && $(echo $test_case | grep -q -e $from)
	then
		skip=false
	fi
	if ! $skip && test -n "$stop_before" && $(echo $test_case | grep -q -e $stop_before)
	then
		skip=true
	fi
	if $skip || $(test -n "$exclude_filter" && $(echo $test_case | grep -Eq -e "$exclude_filter"))
	then
		if ! $show_filter
		then
			echo "Skipping $test_case"
		fi
		continue
	fi
	if $show_filter
	then
		filter_to_report="$filter_to_report $test_case"
	else
		echo
		echo "____________________________________________"
		echo "Running test case $test_case as $user_filter"
		echo "____________________________________________"
		echo
		if ! $dry
		then
			if $need_root && test "$(whoami)" != root
			then
				test "$arch" != L && print_error_and_exit "This test set should be run as root"
				sudo -E -n ./$test_case < /dev/null
			else
				if test -n "$user_filter" -a "$(whoami)" != "$user_filter"
				then
					hook_user=$user_filter
					sudo -u $user_filter -E -n ./$test_case < /dev/null
				else
					./$test_case < /dev/null
				fi
			fi
		fi
	fi
done

if $show_filter
then
	echo "$filter_to_report"
else
	echo "All tests passed"
	echo "Tests took $(( $(( $(perl -e 'print time;') - $test_start )) / 60 )) minutes"
fi
