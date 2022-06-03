#!/usr/bin/env bash

### Make kafka topic list same way as after The Platform fresh install.

whitelist="^_|^MCC$|^__consumer_offsets$|_director.Domain$|_director.GWITH$|_director.GWO$|_director.MCC$|_director.OPERATION_CONTEXT$|_director.OSI_SYSTEM$"
existing_topics=$(sudo -i -u hpossadm /opt/UMB/kafka/bin/kafka-topics.sh --zookeeper localhost:2181 --list)
for topic in $existing_topics; do
	if ! echo "$topic" | grep -q -E "$whitelist"; then
		echo "Topic $topic is going to be deleted"
		sudo -i -u hpossadm /opt/UMB/kafka/bin/kafka-topics.sh --zookeeper localhost:2181 --delete --topic $topic
	else
		echo "Topic $topic left intact"
	fi
done
