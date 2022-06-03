#!/usr/bin/env bash

### Saves size of the log file in the beginning of each test

if test -f "$productA_log_file"
then
	hook_productA_log_file_size=$(get_file_size "$productA_log_file")
else
	hook_productA_log_file_size=0
fi

test_case_productA_log_file_ignore_mask="PATTERN_THAT_MATCHES_NOTHING"
