#!/usr/bin/env bash

###
### Java detection.
###

### $JAVA, $JPS, $JMAP, $JINFO, $JSTACK, $KEYTOOL, $JCMD: paths to java tools.
if test "${JAVA_HOME:-x}" != "x"
then
	JAVA="$JAVA_HOME/bin/java"
	JPS="$JAVA_HOME/bin/jps"
	JMAP="$JAVA_HOME/bin/jmap"
	JINFO="$JAVA_HOME/bin/jinfo"
	JSTACK="$JAVA_HOME/bin/jstack"
	KEYTOOL="$JAVA_HOME/bin/keytool"
	JCMD="$JAVA_HOME/bin/jcmd"
	JAR="$JAVA_HOME/bin/jar"
else
	JAVA=java
	JPS=jps
	JMAP=jmap
	JINFO=jinfo
	JSTACK=jstack
	KEYTOOL=keytool
	JCMD=jcmd
	JAR=jar
fi
