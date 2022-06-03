import static Exec.shell

new Simulator()({
    // Given
    annotate_action "Send an event from EMS to have something in statistics"
    emsSendEvents("""[
{
  "notificationType": "notifyNewAlarm",
  "alarmType": "CommunicationsAlarm",
  "objectClass": "OT_PHYSICAL_TERMINATION_POINT",
  "objectInstance": "deviceID=3,sourceID=C,sourceIP=192.168.0.1,elementType=NodeB",
  "notificationId": 123,
  "correlatedNotifications": [1, 2],
  "eventTime": "1997-01-01T12:00:27.87+00:20",
  "systemDN": "DC=www.huawei.com , SubNetwork=1 , ManagementNode=1 , IRPAgent=1",
  "alarmId": "AMS:5654",
  "agentEntity": "SHOULD NOT BE USED BY ADAPTER",
  "probableCause": "fire",
  "perceivedSeverity": "Critical",
  "specificProblem": ["example specific problem 1"],
  "additionalText": "Everything is on fire!",
  "siteLocation": "Lindau",
  "regionLocation": "Bavaria",
  "vendorName": "Hewlett Packard Enterprise",
  "technologyDomain": "Mobile",
  "equipmentModel": "MNM 3000",
  "plannedOutageIndication": false,
  "customStringAttribute": "custom string value",
  "customListAttribute": ["custom value 1", "custom value 2", "custom value 3"]
}
]""")
    annotate_action "Wait for alarm to be received"
    LibCheck.waitOcAlarms()
    shell($/clear_oc $$oc_1/$)
    // When
    annotate_action "Call ClearStatus directive on global class instance related to productA to clear statistics"
    Exec.shell($/$$manage clearstatus $$gc_1 $$ems_1/$).tap {
        // Then
        annotate_check "Check reply from productA indicates success"
        LibCheck.assertAllPatternsFound(it.join("\n"), [/finished/])
    }
    annotate_action "Send an alarm from EMS to have something in statistics"
    emsSendEvents("""[
{
  "notificationType": "notifyNewAlarm",
  "alarmType": "CommunicationsAlarm",
  "objectClass": "OT_PHYSICAL_TERMINATION_POINT",
  "objectInstance": "deviceID=3,sourceID=C,sourceIP=192.168.0.1,elementType=NodeB",
  "notificationId": 123,
  "correlatedNotifications": [1, 2],
  "eventTime": "1997-01-01T12:00:27.87+00:20",
  "systemDN": "DC=www.huawei.com , SubNetwork=1 , ManagementNode=1 , IRPAgent=1",
  "alarmId": "AMS:5654",
  "agentEntity": "SHOULD NOT BE USED BY ADAPTER",
  "probableCause": "fire",
  "perceivedSeverity": "Critical",
  "specificProblem": ["example specific problem 1"],
  "additionalText": "Everything is on fire!",
  "siteLocation": "Lindau",
  "regionLocation": "Bavaria",
  "vendorName": "Hewlett Packard Enterprise",
  "technologyDomain": "Mobile",
  "equipmentModel": "MNM 3000",
  "plannedOutageIndication": false,
  "customStringAttribute": "custom string value",
  "customListAttribute": ["custom value 1", "custom value 2", "custom value 3"]
}
]""")
    annotate_action "Wait for alarm to be received"
    LibCheck.waitOcAlarms()
    shell($/clear_oc $$oc_1/$)
    annotate_action "Call ShowStatus directive on global class instance related to productA to get its statistics"
    Exec.shell($/$$manage showstatus $$gc_1 $$ems_1/$).tap {
        annotate_check "Check statistics tells about last alarm only"
        LibCheck.assertAllPatternsFound(it.join("\n"), [
                /rt.batch.in.events.*\b1\b/,
        ])
    }
})
