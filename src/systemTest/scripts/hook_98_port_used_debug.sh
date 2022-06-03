#!/usr/bin/env bash

### Collects information about connections and processes to debug issues with resynchronization port being already used.

echo "Connections"
sudo lsof -i -n -P

echo
echo "Processes"
ps -feH
