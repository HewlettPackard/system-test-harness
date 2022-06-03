#!/usr/bin/env bash
### Builds report about tests.

export do_traps=false
. $(cd $(dirname $0) ; pwd)/lib_bootstrap.sh || ( echo "ERROR: Cannot bootstrap" ; exit 1 )

cd $bin_dir

target_dir=$work_dir/doc
mode=text
filter="test_*.sh"
filter_name=""
verbose=true

while test $# -gt 0
do
	option="$1"
	shift
	case "$option" in
	"--text")
		### --text
		### 	Generate tests overview in plain text format (default mode)
		mode=text
	;;
	"--ts")
		### --ts
		### 	Generate test specification (HTML)
		mode=ts
	;;
	"--tr")
		### --tr
		###     Generate test report (HTML)
		mode=tr
	;;
	"--default-filter")
		### --default-filter
		###     Use default filter of run_tests.sh.
		filter=$(harness/run_tests.sh --show-filter)
		filter_name="Default"
	;;
	"--quiet")
		### --quiet
		###     Do not print progress messages, only errors.
		verbose=false
	;;
	*)
		### --<filter name>
		###     Specify filter for tests (same as for run_tests.sh).
		filter=$(harness/run_tests.sh --show-filter $option)
		filter_name="${option#--}"
	;;
	esac
done

if test "$mode" = text
then
	$verbose && printf -- "-- Searching for known bugs\n" 1>&2
	echo "==============================="
	echo "$cfg_name"
	echo "==============================="
	echo
	echo "Known bugs that tests are aware of:"
	! grep -e "QCAF[[:digit:]]" *.sh harness/*.sh | perl -pe 's/.*(QCAF\d+).*/\1/gi' | sort -u
	! grep -e "CR[[:space:]]*[[:digit:]]" *.sh harness/*.sh | perl -pe 's/.*(CR\s*\d+).*/\1/gi' | sort -u
	echo ""
else
	echo "<html><head><title>$cfg_name : $filter_name</title></head><body>"
fi

$verbose && printf -- "-- Caching common functions\n" 1>&2
export doc_cache_dir="$target_dir/doc_cache"
test -d "$doc_cache_dir" && rm -r "$doc_cache_dir"
mkdir -p "$doc_cache_dir"
for lib in harness/lib_*.sh lib_*.sh
do
	$verbose && printf -- "--- Caching functions in library $lib\n" 1>&2
	for func_name in $(grep -E "^function[[:blank:]]+[[:alnum:]_]+[[:blank:]]*\{" $lib | awk '{print $2}'  | cut -d { -f 1)
	do
		$verbose && printf -- "---- Caching function $func_name\n" 1>&2
		grep -vE '^[[:blank:]]*#' $lib | perl -W -007 -pe "s!.*function\s+$func_name\s*{([^}]+)}.*!\$1!gsm" | report_mode=$mode perl harness/extract_test_doc.pl donotrecurse > "$doc_cache_dir/$func_name"
	done
done

$verbose && printf -- "-- Caching groovy scripts\n" 1>&2
if ls test_*.groovy 1>/dev/null 2>&1
then
	for script in test_*.groovy
	do
		$verbose && printf -- "--- Caching documentation for groovy script $script\n" 1>&2
		(cat "$script" | report_mode=$mode perl -W "harness/extract_test_doc.pl" donotrecurse > "$doc_cache_dir/$script")
	done
fi

for script in $(ls -1 $filter)
do
	$verbose && printf -- "-- Processing $script\n" 1>&2
	if grep -q 'test_case_when' $script
	then
		if eval "$(grep 'test_case_when' $script | cut -d '"' -f 2)"
		then
			export is_supported=true
		else
			export is_supported=false
		fi
	else
		export is_supported=true
	fi
	if test "$mode" != text
	then
		cat "$script" | report_mode=$mode perl -W "harness/extract_test_doc.pl" "$script"
	else
		if $is_supported
		then
			echo "TEST: $(basename $script)"
			echo ""
			cat "$script" | report_mode=$mode perl -W "harness/extract_test_doc.pl" "$script"
		else
			echo "TEST: $(basename $script) - Functionality not supported"
		fi
		echo
	fi
done

if test "$mode" != text
then
	echo "</body></html>"
fi

true
