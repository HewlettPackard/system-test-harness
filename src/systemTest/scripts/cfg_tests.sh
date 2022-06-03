#!/usr/bin/env bash

###
### Defines test sets.
###

### $cfg_name : name of this test package
cfg_name="Integration tests"

### Filters that define test sets and their properties.
###   Inclusion filter:
###     cfg_filter_include_<test set name>="<regexp>"
###   Exclusion filter:
###     cfg_filter_exclude_<test set name>="<regexp>"
###     If either inclusion or exclusion filter is not specified
###     then default one is used.
###   Additional flags:
###     cfg_filter_flags_<test set name>="<flags>"
###   Flags could be:
###     disable_traps - if test set fails then no hooks are run
###   Required used:
###     cfg_filter_user_<test set name>="<user name>"
###     If required user is not set then user is not checked or changed automatically.

# 0xxx Common prepare
# 01xx Check prerequisites
# 02xx Prepare ProductB
# 09xx Finish prepare
cfg_filter_include_prepare="test_0[0-9]{3}"
cfg_filter_flags_prepare="disable_traps"

# 9xxx Common cleanup
# 90xx Check cleanup prerequisites
# 97xx Cleanup ProductB
# 98xx Post cleanup reserved
cfg_filter_include_cleanup="test_9[0-9]{3}"

# x0xx Per-test set prepare
# x9xx Per-test set cleanup

# Smoke test set that verifies minimal working of both channels.
# Should not be included in FTS/FTR.
cfg_filter_include_smoke="$cfg_filter_include_prepare|test_1200|test_2000|test_2102|test_2103|test_2120|test_2302|test_3002|test_3110|test_3130|test_3997|test_3999|$cfg_filter_include_cleanup"

#report;1;rt;Integration tests for real time event notification
cfg_filter_include_rt="$cfg_filter_include_prepare|test_2[0-9]{3}|$cfg_filter_include_cleanup"

#report;3;resync;Integration tests for resynchronization
cfg_filter_include_resync="$cfg_filter_include_prepare|test_3[0-9]{3}|$cfg_filter_include_cleanup"

#report;4;ack;Integration tests for acknowledgment
cfg_filter_include_ack="$cfg_filter_include_prepare|test_4[0-9]{3}|$cfg_filter_include_cleanup"

#report;6;commands;Integration tests for commands
cfg_filter_include_commands="$cfg_filter_include_prepare|test_6[0-9]{3}|$cfg_filter_include_cleanup"

#report;8;multi_ems;Integration tests for multiple EMS instances
cfg_filter_include_multi_ems="$cfg_filter_include_prepare|test_8[0-9]{3}|$cfg_filter_include_cleanup"

# Mandatory default filters
### $cfg_filter_include_default : default inclusion filter
###     Used when no option is specified on command line or no inclusion
###     pattern is specified for named filter.
cfg_filter_include_default="test_[0-9]{4}"
### $cfg_filter_exclude_default : default exclusion filter
###     Used when no option is specified on command line or no exclusion
###     pattern is specified for named filter.
cfg_filter_exclude_default="filter-that-matches-nothing---------"
