#!/usr/bin/env bash

### Checks log file for log4j messages with ERROR log level at the end of each test

productname1_crnumber1_error_mask="THIS_IS_AN_EXAMPLE_FOR_FUTURE"
productname2_crnumber2_error_mask="THIS_IS_AN_EXAMPLE_FOR_FUTURE"

default_ignore_mask="$productname1_crnumber1_error_mask|$productname2_crnumber2_error_mask"

problem_identifier_mask="^[0-9]{4}-[0-2][0-9]-[0-3][0-9] [0-2][0-9]\:[0-5][0-9]\:[0-5][0-9]\,[0-9]{3} ERROR"
log_entry_mask="^[0-9]{4}-[0-2][0-9]-[0-3][0-9] [0-2][0-9]\:[0-5][0-9]\:[0-5][0-9]\,[0-9]{3} (TRACE|DEBUG|INFO|WARN|ERROR)\s+"

check_log_file_for_problems "$productA_log_file" "$hook_productA_log_file_size" "$log_entry_mask" "$problem_identifier_mask" "($default_ignore_mask|$test_case_productA_log_file_ignore_mask)"
