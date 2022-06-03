#!/usr/bin/env bash
### Cleanup environment after test failure.

export do_traps=false
export testset=${testset:-recover}
. $(cd $(dirname $0) ; pwd)/lib_bootstrap.sh || ( echo "ERROR: Cannot bootstrap" ; exit 1 )

on_exit

for dir in "$fake_root/opt"/* "$fake_root/var/opt"/* "$fake_root/home"/* "$fake_root/tmp"/* "$tmp_dir"/* "$work_dir/pids"
do
	if test -e "$dir"
	then
		if test -d "$dir"
		then
			clean_dir "$dir"
		else
			rm "$dir" < /dev/null
		fi
	fi
done

rm -f $work_dir/*.tmp
