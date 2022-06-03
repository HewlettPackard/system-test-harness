#!/usr/bin/env bash
### A library for unit testing shell libraries.
###
### If currently executed file name starts with lib_
### then all functions defined in that file that
### start with _test_ will be executed.
### Testing stops if any of these functions fails.
### Fails means that any command within these functions
### returns unhandled non-zero exit code or undefined
### variable is used.
### Be warned that no other libraries will be automatically
### loaded except libs specified in _test_dependencies.
### _test_dependencies is an optional variable that could be
### to a space separated list of libraries that should
### be loaded before any test function is run.
### Only suffix of dependency library needs to be specified.
### That means that if library under test requires
### lib_07_log.sh to be loaded first then you
### should set _test_dependencies="log".
###
### For this library to correctly find and execute all
### test functions, it must be loaded as very last
### statement of the library under test.

if echo $0 | grep -qE "lib_.*.sh"
then
	set -o nounset
	set -o errexit
	echo -e "\t* Unit testing $0"
	dependencies=$(perl -W -ne "if(\$_ =~ /^_test_dependencies\s*=\s*[\"']?(.*)[\"']?\s*\$/){print \$1;}" $0)
	for lib in $dependencies
	do
		echo -e "\t\t* Loading '$lib' for dependency"
		. ./lib_*_$lib.sh
	done
	tests=$(perl -W -ne "if(\$_ =~ /^\s*function\s*(_test_\w+)\s*{\s*$/){print \"\$1 \";}" $0)
	for func in $tests
	do
		echo -e "\t\t* Running test '$func'"
		eval $func
	done
	echo -e "\t* All unit tests passed"
fi
