new Simulator()({
    // Given
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
    LibCheck.waitOcAlarms()
    // When
    Exec.shell($/$$manage showstatus $$gc_1 $$ems_1/$).tap {
        // Then
        LibCheck.assertAllPatternsFound(it.join("\n"), [
                /Connected = "true"/
        ])
    }
})
