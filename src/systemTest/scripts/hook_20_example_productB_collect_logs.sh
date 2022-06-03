#!/usr/bin/env bash

### Copies ProductB logs to build directory before other hooks delete everything from Platform directory.
### This greatly facilitates troubleshooting.

find /var/opt/Platform/trace/ -type f -name "$PRODUCTB_NAME*.log" | xargs -i cp -v {} $work_dir

cp -v "/var/opt/Platform/install/install.$PRODUCTB_PACKAGE_NAME" "$work_dir/install.$PRODUCTB_PACKAGE_NAME.log"
