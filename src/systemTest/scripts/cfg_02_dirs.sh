#!/usr/bin/env bash

# Configuration of directories.

### $cfg_tests_work_dir : path to working directory for tests
export cfg_tests_work_dir="$TMP_DIR/systemTest"

if test -n "${JENKINS_HOME:-}"
then
	# Jenkins unstashes like everything was build on the same machine in the current directory
	export BUILD_DIR=$WORKSPACE/build
fi
