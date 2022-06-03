#!/usr/bin/env bash
### Runs command in test environment
###     Usage: execute_cmd.sh command
###     Example: ./execute_cmd.sh '$nom_admin --list-container'

export do_traps=false
. $(cd $(dirname $0) ; pwd)/lib_bootstrap.sh || ( echo "ERROR: Cannot bootstrap" ; exit 1 )

mkdir -p ./harness

eval "$@"
