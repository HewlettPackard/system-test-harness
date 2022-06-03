#!/usr/bin/env bash

### Configuration of simulator.

SIM_BASE_CP="$bin_dir/simulator:$BUILD_DIR/libs/simulator/*:$expanded_productA_simulator:$expanded_productA_simulator/*"
simulator_cp_extra="\$productA_lib:\$productA_home/lib_extra:\$productA_home/lib_extra/*"

# You can always override this environment variable in a specific test case to use different parameters.
export SIM_OPTS=$(
	echo "
	_=EMS_simulator
	emsVersion=1.0.0
	productARtListenPort=$productARtListenPort
	emsActionListenPort=$emsActionListenPort
	_=PRODUCTB_simulator
	simulateAm=false
	" | while read line
do
	echo -n "$line;"
done
)

SIM_JAVA_OPTS="-Dlog4j2.configurationFile=log4j2-simulator.properties"
