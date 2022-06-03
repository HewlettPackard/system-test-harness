#!/usr/bin/env bash

### Copies productC logs to build directory before other hooks delete everything from Platform directory.
### This greatly facilitates troubleshooting.

cp -v "/var/opt/Platform/install/install.$PRODUCTC_PACKAGE_NAME" "$work_dir/install.$PRODUCTC_PACKAGE_NAME.log"
