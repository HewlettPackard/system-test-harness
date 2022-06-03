#!/usr/bin/env bash

### Forcibly stops productA.

for pid in $(ps --no-headers -eo pid,cmd | grep -E "[D]appName=$PRODUCTA_NAME" | awk '{print $1}')
do
	gentle=false killtree $pid
done
