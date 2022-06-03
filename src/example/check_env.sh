#!/usr/bin/env bash
### The script can be run as the following:
### ./check_env.sh A002test
### Where:
### - A is product name
### - 002 is environment (or product) version
### - test is mode
### All these parts correspond to functions defined further like the following:
### - check_A_ANY
### - check_A_002_ANY
### - check_A_002_kit_os_L_8_ANY
### - There can be any number of such functions that are as specific or as generic as needed.
### The script takes product name, version and mode and optionally OS name/version
### (or other environment characteristics) and tries to match defined functions.
### Then the script runs matching functions to verify that environment conforms to their requirements.
### If all functions report compliance then the environment is ok for building or testing
### specific version of the product.
### This system allows high degree of flexibility over OS family/version/etc.
### You can customize how functions are matched by customizing
### create_config_label function.
### See examples of checking functions below "BEGIN: Customizable part".

### BEGIN: Non customizable part
set -o errexit
set -o nounset

performed_checks=''
function run_checks {
	local pattern="$1"
	local check
	echo "INFO Looking for checks matching '$pattern'..."
	# First run generic checks then specialized
	# The shorter name is the more generic check is
	for check in $(perl -W -ne 'if(/function\s+check_\w+/){s/\s*function\s+check_([^\s]+)\s*{\s*/$1/;print $_."\n";}' $0 | perl -W -pe 's/ANY/*/g' | xargs -i sh -c 'printf "$(echo "{}"|wc -c)\t{}\n"' | sort -n -k 1 | cut -f 2- | perl -W -pe 's/\*/ANY/g')
	do
		local pattern_from_check_name="$(echo $check|perl -W -pe 's/ANY/.*/g;s/_PATTERNSTOP.*//')"
		if echo "$pattern" | grep -x -q -E "$pattern_from_check_name"
		then
			if echo "$performed_checks" | grep -q -x "$check"
			then
				continue
			else
				performed_checks="$performed_checks\n$check"
			fi
			echo "INFO Running check $check"
			if ! check_$check
			then
				echo "ERROR: Environment check failed! Failed check is '$check'"
				exit 1
			fi
		else
			true
			#Uncomment to debug check name matching against label name
			#echo "pattern $pattern_from_check_name did not match $pattern ($pattern_from_check_name)"
		fi
	done
}
function annotate_assert {
	local name="$1"
	local additional="$2"
	if $(eval \${ignore_assert_$name:-false})
	then
		echo "... skipped assert_$name"
		return 1
	else
		echo "... checking assert_$name: $additional"
		return 0
	fi
}
cache_os_name=$(uname -s)
function get_os_name {
	if test -n "${override_os_name:-}"
	then
		echo $override_os_name
	else
		if test "$cache_os_name" = Linux
		then
			echo L
		else
			echo I
		fi
	fi
}
function get_rhel_version {
	perl -W -pe 's/.*?(\d+)\.(\d+).*/$1_$2/' /etc/redhat-release
}
function get_hpux_version {
	uname -r | cut -d . -f 2- | tr . _
}
function get_os_version {
	if test -n "${override_os_version:-}"
	then
		echo $override_os_version
	else
		if test "$cache_os_name" = Linux
		then
			get_rhel_version
		else
			get_hpux_version
		fi
	fi
}
function assert_os_name {
	local pattern="$1"
	annotate_assert os_name "$pattern vs $(get_os_name)" || return 0
	get_os_name | grep -x -q -E "$pattern"
}
function assert_os_version {
	local pattern="$1"
	annotate_assert os_version "$pattern vs $(get_os_version)" || return 0
	get_os_version | grep -x -q -E "$pattern"
}
function assert_java_version {
	local pattern="$1"
	if test "${JAVA_HOME:-x}" != "x"
	then
		local JAVA=$JAVA_HOME/bin/java
	else
		local JAVA="java"
	fi
	annotate_assert java_version "$pattern vs $($JAVA -version 2>&1 | grep -i version | head -n 1)" || return 0
	$JAVA -version 2>&1 | grep -i version | head -n 1 | perl -W -pe 's/.+?(\d+)[_\.](\d+)[_\.](\d+)[_\.](\d+).*/$2_$4/' | grep -x -q -E "$pattern"
}
function assert_rpm_installed {
	local name="$1"
	annotate_assert rpm_installed $1 || return 0
	rpm --quiet -q $1
}
### END: Non customizable part

### ========================= BEGIN: Customizable part =======================
function create_config_label {
	echo ${product_name}_${product_version}_${product_mode}_os_$(get_os_name)_$(get_os_version)
}

function check_A_ANY {
	# Could be a check here for any version of product A for any mode.
	true
}

function check_A_002_ANY {
	# Checking any mode of product A for version 002.
	assert_os_name "L" && \
	assert_os_version "7_.*" && \
	assert_java_version "8_.*" && \
	true
}
function check_A_002_kit_ANY {
	# When building version 002 of product A, we need graphviz rpm to be installed.
	assert_rpm_installed graphviz && \
	true
}
function check_A_002_kit_os_L_7_ANY {
	# When building product A version 002 on RHEL 7, this is what is required to be installed.
	assert_rpm_installed rh-python38 && \
	assert_rpm_installed rh-python38-python-pip && \
	assert_rpm_installed docker && \
	true
}
function check_A_002_kit_os_L_8_ANY {
	# This will fail the check if someone tries to build product A version 002 on RHEL 8.
	false
}
function check_A_002_test_ANY {
	# This is what needed to run (test) the product A version 002 on any OS.
	# Essentially, those are system requirements.
	assert_rpm_installed bash && \
	assert_rpm_installed gnupg2 && \
	assert_rpm_installed gawk && \
	assert_rpm_installed procps-ng && \
	assert_rpm_installed util-linux && \
	assert_rpm_installed grep && \
	assert_rpm_installed curl && \
	assert_rpm_installed wget && \
	assert_rpm_installed bzip2 && \
	true
}
# It is helpful when we add checks for new versions on top and leave old checks for old versions at bottom
# without touching them.
# Changing some system requirement means NEW environment.
# Versions do not really mean product versions. They're actually versions of build or runtime environments.
# The same environment could be used for multiple product versions.
# The same way, 2nd or 3rd OS version support could be added to existing product version.
# This would be new environment but the product version would not change.
function check_A_001_ANY {
	assert_os_name "L" && \
	assert_os_version "7_.*" && \
	assert_java_version "8_.*" && \
	true
}
function check_A_001_kit_ANY {
	assert_rpm_installed graphviz && \
	true
}
function check_A_001_kit_os_L_7_ANY {
	assert_rpm_installed rh-python38 && \
	assert_rpm_installed rh-python38-python-pip && \
	assert_rpm_installed docker && \
	true
}
function check_A_001_kit_os_L_8_ANY {
	false
}
function check_A_001_test_ANY {
	assert_rpm_installed bash && \
	assert_rpm_installed gnupg2 && \
	assert_rpm_installed gawk && \
	assert_rpm_installed procps-ng && \
	assert_rpm_installed util-linux && \
	assert_rpm_installed grep && \
	assert_rpm_installed curl && \
	assert_rpm_installed wget && \
	assert_rpm_installed bzip2 && \
	true
}
### ==========================END: Customizable part   =======================

### BEGIN: Non customizable part
if test --help = "${1:-}"
then
	echo "Run environment checks for specified label"
	echo "Usage: $(basename "$0") <LABEL>"
	echo "LABEL=<product prefix><product version><product mode>"
	echo "Label examples: n71kit, t21test"
	echo "To disable check use the following form ignore_assert_java_version=true ignore_assert_rhel_version=true ./check_env.sh n71test"
	exit 0
fi
label=$1
fielded_label=$(echo $label | perl -W -pe 's/([[:alpha:]]+)([\d]+)([[:alpha:]]+)/$1\t$2\t$3/')
product_name=$(echo "$fielded_label" | cut -f 1)
product_version=$(echo "$fielded_label" | cut -f 2)
product_mode=$(echo "$fielded_label" | cut -f 3)
echo "INFO Checking label '$label' for product '$product_name' version '$product_version' mode '$product_mode'"
run_checks "$(create_config_label)"
echo "INFO All environment checks are successful"
### END: Non customizable part
