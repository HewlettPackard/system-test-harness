#!/usr/bin/env bash

function flow_prepare {
	### Cleanup and check OC for first EMS instance.
	annotate_action "Cleanup OC for first EMS instance"
	verbose_exec=false silent=true clear_oc $oc_1
	annotate_check "Check OC for first EMS instance is in good shape"
	confidence=0 verbose=false modifier="all attributes" wait_for_oc_content $oc_1 'contains "Operational state = Enabled"'
}

function flow_cleanup {
	### Cleanup OC for first EMS instance.
	annotate_action "Cleanup OC for first EMS instance"
	verbose_exec=false silent=true clear_oc $oc_1
}

function flow_prepare_all {
	### Cleanup and check all OCs.
	annotate_action "Cleanup OCs for all EMS instances"
	clean_default_ocs
}

function flow_cleanup_all {
	### Cleanup all OCs.
	annotate_action "Cleanup OCs for all EMS instances"
	clean_default_ocs
}
