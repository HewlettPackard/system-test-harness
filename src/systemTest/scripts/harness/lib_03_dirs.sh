#!/usr/bin/env bash
### Library that declares paths to necessary directories.
### It automatically changes current directory to $work_dir
###

cd $work_dir

if ! test -d "$tmp_dir"
then
	mkdir -p "$tmp_dir"
fi

for dir in opt var/opt home tmp
do
	mkdir -p "$fake_root/$dir"
done
