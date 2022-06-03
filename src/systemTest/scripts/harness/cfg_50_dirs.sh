#!/usr/bin/env bash
### Configuration of directories.

### $work_dir: Working directory.
### Products under test are installed in this directory.
### Any temporal files also are created there.
if echo "$cfg_tests_work_dir" | grep -q -E "^/"
then
	work_dir="$cfg_tests_work_dir"
else
	work_dir="$bin_dir/$cfg_tests_work_dir"
fi
if ! test -d "$work_dir"
then
	mkdir -p $work_dir
fi
export work_dir=$(cd $work_dir; pwd)

### $tmp_dir: directory for temporary files
tmp_dir="$work_dir/tmp"

### $fake_root: Path to be used instead of /
### If original path was /opt/UMB then $fake_root/opt/UMB should be used instead
export fake_root="${fake_root:-$tmp_dir}"

### $rpmdb_dir: Path to rpm database
if test "$(uname -s)" = Linux
then
	if test "$(whoami)" = root
	then
		rpmdb_dir=MUST_NOT_BE_REFERENCED
	else
		rpmdb_dir="$tmp_dir/rpmdb"
	fi
fi
