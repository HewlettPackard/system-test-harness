#!/usr/bin/env bash

### ProductA configuration parameters for tests.
###
### Be sure not to export those variables as they'll override content of configuration files.

### $productA_kit_dir : A directory with kit of productA.
productA_kit_dir="$BUILD_DIR/libs/ProductA"

### $productA_install_root : Root directory where productA will be installed.
productA_install_root="$fake_root/opt"

### $productARtListenPort : Network port where productA will listen for real time events.
productARtListenPort=12345

### $productAActionListenPort : Network port where productA will listen for resynchronization requests from productB.
productAActionListenPort=12346

### $emsActionListenPort : Network port where EMS is expected to receive resynchronization requests.
# The Platform is likely to use ports from 9000 to 65K. So try not to use those ports.
# The following port interval is likely to be free.
# 6002       - 7104       => 1102
# Use the following ports where simulator should listen for requests from productA:
# 6111 - instance 1, channel 1
# 6112 - instance 1, channel 2
# 6113 - instance 1, channel 3
# 6211 - instance 2, channel 1
# 6212 - instance 2, channel 2
# 6213 - instance 2, channel 3
# etc
emsActionListenPort=6111

# Usually, those variables should come from test archive of the corresponding product
# and then loaded in cfg_01_gradle.sh.
# This allows evolution of products without too much maintenance effort on system tests.
PRODUCTA_NAME="productA"
PRODUCTA_VERSION_FULL="1.0.0"
HAS_DOWN_ACK=true
HAS_RAISE=true
HAS_RESYNC=true
HAS_SHOW_STATUS_SUPPORT=true
HAS_UP_ACK=true
