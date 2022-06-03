#!/usr/bin/env bash
### Generates STS and STR.
###
### Usage:
### generate_sts_str.sh
###
### The structure of STS and STR is described by cfg_tests.sh
### that should contain one or more records of the following format:
### #report;order;testsetname;testsettitle
### Where
### order - a number to order chapters in STS/STR
### testsetname - name of test set, the same as to be passed to runtests.sh
### testsettitle - human readable title of the test

export do_traps=false
. $(cd $(dirname $0) ; pwd)/lib_bootstrap.sh || ( echo "ERROR: Cannot bootstrap" ; exit 1 )

cd $bin_dir

target_dir=$work_dir/doc
mkdir -p $target_dir
ts="$target_dir/ts.html"
tr="$target_dir/tr.html"

echo "<html><head><title>Test specification</title></head><body>" > $ts
echo "<html><head><title>Test report</title></head><body>" > $tr

echo "<h1>Summary</h1>" >> $tr
echo "<table border='1'><tr><th>Test set</th><th>Passed</th><th>Failed</th><th>Unsupported</th><th>Comments</th></tr>" >> $tr
cat cfg_tests.sh | grep '#report;' | sort -n -t \; -k 2 | \
while read rec
do
	testsetname=$(echo "$rec" | cut -d \; -f 3)
	testsettitle="$(echo "$rec" | cut -d \; -f 4)"
	echo "- Get statistics for $testsettitle" 1>&2
	num_tests=$(./harness/run_tests.sh --show-filter --$testsetname | wc -w)
	num_failed=0
	num_unsupported=0
	comments=""
	for script in $(./harness/run_tests.sh --show-filter --$testsetname)
	do
		if grep -q 'test_case_when' $script
		then
			if eval "$(grep 'test_case_when' $script | cut -d '"' -f 2)"
			then
				is_supported=true
			else
				num_unsupported=$(($num_unsupported + 1))
				is_supported=false
			fi
		else
			is_supported=true
		fi
		if $is_supported && grep -q -m 1 'test_case_fails' $script
		then
			num_failed=$(($num_failed + 1))
			test_failures="$(grep 'test_case_fails' $script | cut -d '"' -f 2 | xargs -i printf '%s\n' '{}')"
			comments="$(printf '%s\n%s' "$comments" "$test_failures")"
		fi
	done
	comments="$(echo "$comments" | sort -u | xargs -i printf '<p>%s</p>\n' '{}')"
	echo "<tr><td>$testsettitle</td><td>$(($num_tests - $num_failed - $num_unsupported))</td><td>$num_failed</td><td>$num_unsupported</td><td>$comments</td></tr>" >> $tr
done
echo "</table>" >> $tr

echo "<h1>Test case details</h1>" >> $tr
cat cfg_tests.sh | grep '#report;' | sort -n -t \; -k 2 | \
while read rec
do
	testsetname=$(echo "$rec" | cut -d \; -f 3)
	testsettitle="$(echo "$rec" | cut -d \; -f 4)"
	echo "- Get report for $testsettitle" 1>&2
	echo "<h1>$testsettitle</h1>" >> $ts
	./harness/extract_info.sh --ts $testsetname | grep -E -v '</body></html>|<html><head><title>' >> $ts
	echo "<h2>$testsettitle</h2>" >> $tr
	./harness/extract_info.sh --tr $testsetname | grep -E -v '</body></html>|<html><head><title>' >> $tr
done
echo "</body></html>" >> $ts
echo "</body></html>" >> $tr
