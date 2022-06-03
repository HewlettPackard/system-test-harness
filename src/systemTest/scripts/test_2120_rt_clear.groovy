import static Exec.shell

new Simulator()({
    // When
    annotate_action "Send an alarm"
    emsSendEvents([[
                           "notificationType"       : "notifyNewAlarm",
                           "alarmType"              : "EquipmentAlarm",
                           "objectClass"            : "OT_PHYSICAL_TERMINATION_POINT",
                           "objectInstance"         : "deviceID=3,sourceID=C,sourceIP=192.168.0.1,elementType=NodeB",
                           "notificationId"         : 123,
                           "correlatedNotifications": [1, 2],
                           "eventTime"              : "1997-01-01T12:00:27.87+00:20",
                           "systemDN"               : "DC=www.huawei.com , SubNetwork=1 , ManagementNode=1 , IRPAgent=1",
                           "alarmId"                : "123456",
                           "agentEntity"            : "SHOULD NOT BE USED BY ADAPTER",
                           "probableCause"          : "fire",
                           "perceivedSeverity"      : "Minor",
                           "specificProblem"        : ["example specific problem 1"],
                           "additionalText"         : "Everything is on fire!",
                           "siteLocation"           : "Lindau",
                           "regionLocation"         : "Bavaria",
                           "vendorName"             : "Hewlett Packard Enterprise",
                           "technologyDomain"       : "Mobile",
                           "equipmentModel"         : "MNM 3000",
                           "plannedOutageIndication": false,
                           "customStringAttribute"  : "custom string value",
                           "customListAttribute"    : ["custom value 1", "custom value 2", "custom value 3"]
                   ]])
    annotate_check "Check that AO with Perceived Severity = Minor was created in OC"
    shell($/wait_for_oc_content $$oc_1 'test $$count -eq 1 && contains "Perceived Severity = Minor"'/$)
    annotate_check "Check optional Additional Text has been mapped correctly"
    LibCheck.unpackOcAlarm(shell($/cat $$0.tmp | extract_alarms_from_oc/$).first()).tap {
        assert it['Additional Text'] =~ /Everything is on fire!/
    }
    annotate_action "Send clearance for the alarm that contains additional text change"
    emsSendEvents([[
                           "notificationType"       : "notifyClearedAlarm",
                           "correlatedNotifications": [1, 2],
                           "eventTime"              : "1997-01-01T12:00:27.88+00:20",
                           "systemDN"               : "DC=www.huawei.com , SubNetwork=1 , ManagementNode=1 , IRPAgent=1",
                           "alarmId"                : "123456",
                           "agentEntity"            : "SHOULD NOT BE USED BY ADAPTER",
                           "perceivedSeverity"      : "Cleared",
                           "additionalText"         : "Fire was extinguished",
                           "customStringAttribute"  : "custom string value",
                           "customListAttribute"    : ["custom value 1", "custom value 2", "custom value 3"]
                   ]])
    // Then
    annotate_check "Check AO in OC has been cleared"
    shell($/wait_for_oc_content $$oc_1 'test $$count -eq 1 && contains "Clearance Report Flag = True"'/$)
    LibCheck.unpackOcAlarm(shell($/cat $$0.tmp | extract_alarms_from_oc/$).first()).tap {
        annotate_check "Check AO in OC is cleared via Clearance Report Flag = True but Original Severity and Perceived Severity is preserved"
        assert it[/Clearance Report Flag/] == true
        assert it[/Original Severity/] == /Minor/
        assert it[/Perceived Severity/] == /Minor/
        annotate_check "Check original Additional Text has not changed"
        // Because this is not supported by AHFM.
        // Once support is added in AHFM, add another test case to make
        // sure we do not corrupt original Additional Text when we sent clear
        // from EMS and not specify that Additional Text was changed.
        assert it['Additional Text'] =~ /Everything is on fire!/
        annotate_check "Check Original Event Time did not change"
        assert it['Original Event Time'] ==
                java.time.OffsetDateTime.parse("1997-01-01T12:00:27.87+00:20").toInstant()
        annotate_check "Check Event Time did not change"
        assert it['Event Time'] ==
                java.time.OffsetDateTime.parse("1997-01-01T12:00:27.87+00:20").toInstant()
        annotate_check "Check Clearance Time Stamp is set to eventTime in notifyClearedAlarm"
        assert it['Clearance Time Stamp'] ==
                java.time.OffsetDateTime.parse("1997-01-01T12:00:27.88+00:20").toInstant()
    }
})
