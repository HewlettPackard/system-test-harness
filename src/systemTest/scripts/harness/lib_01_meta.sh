#!/usr/bin/env bash

###
### Shell meta-programming functions.
###

function get_value_of {
	### Gets value of specified variable.
	### This is useful when you need to construct variable name dynamically.
	### Usage: abc=123; prefix=ab; suffix=c ; value="$(get_value_of "${prefix}${suffix}" "default_value")"
	### If you don't specify default value and specified variable is not set then behavior is as per
	### current setting of set -o.
	local var_name="$1"
	local default_value="${2:-}"
	if test $# -eq 1
	then
		echo "$(eval echo "\${$var_name}")"
	else
		echo "$(eval echo "\${$var_name:-\"$default_value\"}")"
	fi
}

function _test_get_value_of {
	### A test to verify get_value_of.
	local abc
	local prefix
	local suffix
	local value
	myvar=123; prefix=my; suffix=var ; value="$(get_value_of "$prefix$suffix")"
	test "$myvar" = "$value" || echo "ERROR: get_value_of dont get proper value of existing variable" || exit 1
	prefix=none; suffix=none ; value="$(get_value_of "$prefix$suffix" "this_is_default_value")"
	test "this_is_default_value" = "$value" || echo "ERROR: get_value_of dont detect when to use default value" || exit 1
	myvar=123; prefix=my; suffix=var ; value="$(get_value_of "$prefix$suffix" "this_is_default_value")"
	test "$myvar" = "$value" || echo "ERROR: get_value_of dont detect when not to use default value" || exit 1
}

function set_value_of {
	### Sets value of specified variable.
	### This is useful when you need to construct variable name dynamically.
	### Usage: value=123; prefix=ab; suffix=c ; set_value_of "${prefix}${suffix}" "$value" ; echo "$abc"
	local var_name="$1"
	local value="$2"
	eval export $var_name="$value"
}

function _test_set_value_of {
	### A test to verify set_value_of.
	local value
	local prefix
	local suffix
	local abc
	value=123 ; prefix=ab ; suffix=c; set_value_of "$prefix$suffix" "$value"
	test "${abc:-"variable abc wasnt set"}" = "$value" || echo "ERROR: set_value_of dont set variable value" || exit 1
}

function find_vars_by_pattern {
	### Prints variables whose name match specified extended pattern.
	### Usage: abc1=a ; abc2=b ; abc3=c ; for var in $(find_vars_by_pattern "abc.*") ; do get_value_of $var ; done
	local pattern="$1"
	set | grep -E '^[[:alnum:]_]+=.*' | cut -d = -f 1 | grep -E "^$pattern\$"
}

function _test_find_vars_by_pattern {
	### A test to verify find_vars_by_pattern.
	local abc_1
	local abc_2
	local abc_3
	local var
	local actual=""
	abc_1=a ; abc_2=b ; abc_3=c ; for var in $(find_vars_by_pattern "abc_.*") ; do actual="$actual$(get_value_of $var)" ; done
	test "abc" = "$actual" || echo "ERROR: find_vars_by_pattern dont print all variables by pattern" || exit 1
}

function is_defined {
	### Checks if variable with specified name is defined.
	### Usage: if ! if_defined "abc" ; then set_value_of "abc" 1 ; fi
	local var_name="$1"
	local salt=$RANDOM
	test "$(eval echo "\${$var_name:-\"$salt undefined\"}")" != "$salt undefined"
}

function _test_is_defined {
	### A test to verify find_vars_by_pattern.
	### This is useful when you need to construct variable name dynamically and
	### want to avoid re-defining it if it's already set.
	local abc=1
	is_defined abc || echo "ERROR: is_defined doesnt find defined variables" || exit 1
	is_defined "non_existing_variable_$RANDOM" && echo "ERROR: is_defined finds undefined variables" && exit 1
	true
}

echo $0 | grep -E "lib_.*.sh" && . $(dirname $0)/libunittest.sh
true
