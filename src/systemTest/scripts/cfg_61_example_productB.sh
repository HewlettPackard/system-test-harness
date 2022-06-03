#!/usr/bin/env bash

### ProductB configuration parameters for tests.

### $productB_kit_dir : A directory with kit of productB.
export productB_kit_dir="$BUILD_DIR/libs/ProductB"

### $platform_user : User account that should be used to run commands for ProductB.
platform_user=user123

# Usually, those variables should come from test archive of the corresponding product
# and then loaded in cfg_01_gradle.sh.
# This allows evolution of products without too much maintenance effort on system tests.
PRODUCTB_NAME="productB"
PRODUCTB_VERSION_FULL="2.0.0"
