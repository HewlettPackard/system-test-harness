#!/usr/bin/env bash

### ProductC configuration parameters for tests.

### $productC_kit_dir : A directory with kit of productC.
export productC_kit_dir="$BUILD_DIR/libs/productC"

# Usually, those variables should come from test archive of the corresponding product
# and then loaded in cfg_01_gradle.sh.
# This allows evolution of products without too much maintenance effort on system tests.
PRODUCTC_NAME="productC"
PRODUCTC_VERSION_FULL="3.0.0"
