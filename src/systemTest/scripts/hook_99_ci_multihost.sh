#!/usr/bin/env bash

### Renames working directory to a test run specific name so it can be properly archived on jenkins.

echo "On CI: $ci, host: $(hostname), test set: $testset, user: $(id)"

$ci || exit 0

target=saved-workdir-${platform_mode:-noplatform}-${testset:-notestset}-$(hostname)-$(date +%F-%H-%M-%S-%N)
mkdir -v $work_dir/$target
find $work_dir -mindepth 1 -maxdepth 1 ! -name "saved-workdir*" -exec mv -v {} $target \;
