#!/usr/bin/env bash
### Set up test environment, load other libraries.
###
### Typical usage is to start harness script as
### #!/usr/bin/env bash
### . $(cd $(dirname $0) ; pwd)/lib_bootstrap.sh || ( echo "ERROR: Cannot bootstrap" ; exit 1 )
###
### In case of script in main directory use the following form
### #!/usr/bin/env bash
### . $(cd $(dirname $0) ; pwd)/harness/lib_bootstrap.sh || ( echo "ERROR: Cannot bootstrap" ; exit 1 )

set -o nounset
set -o errexit

### $bin_dir : directory with test scripts
if test -z "${bin_dir:-}"
then
	if test "$(basename $(cd $(dirname $0);pwd))" = "harness"
	then
		export bin_dir="$(dirname $(cd $(dirname $0) ; pwd))"
	else
		export bin_dir="$(cd $(dirname $0) ; pwd)"
	fi
fi

### $harness_dir : directory with test harness scripts
export harness_dir="$bin_dir/harness/"

### $TESTS_DEBUG : set to true before bootstrapping to enable debug output
export debug=${TESTS_DEBUG:-false}
### $TESTS_VERBOSE : set to false before bootstrapping to disable verbose output
export verbose=${TESTS_VERBOSE:-true}

if $debug
then
	PS4="		| DBG | $0:$LINENO - > "
	set -o xtrace
fi

umask 000

### $TESTS_PROFILE : set to true profile tests.
export TESTS_PROFILE=${TESTS_PROFILE:-false}
### $PROFILE_LOCATION : path to file with tests profiling information.
export PROFILE_LOCATION="$bin_dir/profile.txt"
function reset_profile_result {
	### reset_profile_result: Erases accumulated profiling information.
	if $TESTS_PROFILE
	then
		echo > $PROFILE_LOCATION
	fi
}
### TEST_PROFILE_INFO: Associative map where keys are profiling point ID
### and value is millis from epoch when profiling has started for this profiling point.
if test -z "${!TEST_PROFILE_INFO[@]}"
then
	declare -x -A TEST_PROFILE_INFO
fi
function get_timestamp {
	### get_timestamp: Prints milliseconds from start of the epoch.
	if $TESTS_PROFILE
	then
		echo $(( $(date +%s%N) / 1000000 ))
	fi
}
function start_profile {
	### start_profile POINT_ID: Remember current time for profiling point with ID POINT_ID.
	if $TESTS_PROFILE
	then
		TEST_PROFILE_INFO[$1]=$(get_timestamp)
	fi
}
function get_profile_duration {
	### get_profile_duration POINT_ID: Prints milliseconds duration elapsed for profiling point with ID POINT_ID.
	if $TESTS_PROFILE
	then
		echo $(( $(get_timestamp) - ${TEST_PROFILE_INFO[$1]} ))
	fi
}
function register_profile_result {
	### register_profile_result POINT_ID: Adds into report profiling result for point with ID POINT_ID.
	if $TESTS_PROFILE
	then
		echo "$(get_profile_duration "$1") $1" >> $PROFILE_LOCATION
	fi
}
function print_profile_result {
	### print_profile_result: Prints IDs of profiling points that took most time.
	#local profile_result
	if $TESTS_PROFILE
	then
		declare -A profile_result
		while read line
		do
			local key="${line#* }"
			local value="${line%% *}"
			if test -n "$key"
			then
				profile_result[$key]=$(( $value + ${profile_result[$key]:-0} ))
			fi
		done < $PROFILE_LOCATION
		echo "Profiling information:"
		for key in "${!profile_result[@]}"
		do
			echo "${profile_result[$key]} $key"
		done | sort -n -k 1 -r | head -n 10
	fi
}

if test "${bootstrappedFor:-}" != "$(id -u)"
then
	# Make total ordering of both harness and specific configs and load them in that order.
	# This makes it possible for specific configs to provide data to harness configs.
	tmp_cfg=$(mktemp)
	for dir in $harness_dir $bin_dir
	do
		ls -1 $dir/cfg_*.sh 2>/dev/null
	done | while read path
do
	echo "$(basename "$path") $(dirname "$path")"
done | sort | awk '{print $2"/"$1}' | while read file
do
echo "start_profile \"source $file\"" >> $tmp_cfg
echo ". \"$file\"" >> $tmp_cfg
echo "register_profile_result \"source $file\"" >> $tmp_cfg
done
. $tmp_cfg
rm -f $tmp_cfg

for dir in $harness_dir $bin_dir
do
for file in $(ls -1 $dir/lib_*.sh 2> /dev/null | sort | grep -v lib_bootstrap.sh)
do
	start_profile "source $file"
	. "$file"
	register_profile_result "source $file"
done
done

bootstrappedFor="$(id -u)"
fi
