#!/usr/bin/env bash
. $(cd $(dirname $0) ; pwd)/harness/lib_bootstrap.sh || ( echo "ERROR: Cannot bootstrap" ; exit 1 )

test_case_begin "Prepare simulator"
test_case_goal "Prepare simulator"
test_case_type "Infrastructure"

phase "Preparation"

annotate_action "Fix classloader issues of simulator caused by compiled/interpreted hell"
for script in $expanded_productA_simulator/*.groovy
do
	rm -vf $expanded_productA_simulator/$(basename $script .groovy).class
done

test_case_end
