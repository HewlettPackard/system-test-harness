import java.time.Instant

import static Exec.shell

new Simulator()({
    annotate_action "Send raise alarm event from EMS simulator"
    emsSendEvents("""[
{
  "notificationType": "notifyNewAlarm",
  "alarmType": "CommunicationsAlarm",
  "objectClass": "OT_PHYSICAL_TERMINATION_POINT",
  "objectInstance": "IRPNetwork=ABCNetwork,Subnet=TN2,BSS=B5C0100",
  "notificationId": 123,
  "correlatedNotifications": [1, 2],
  "eventTime": "1997-01-01T12:00:27.87+00:20",
  "systemDN": "DC=www.huawei.com , SubNetwork=1 , ManagementNode=1 , IRPAgent=1",
  "alarmId": "AMS:5654",
  "agentEntity": "ems_1",
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
    annotate_action "Wait for the alarm to be received in OC"
    LibCheck.unpackOcAlarm(LibCheck.waitOcAlarms().first()).tap {
        annotate_check "Check AO Event Time is as in original alarm"
        assert it['Event Time'] ==
                java.time.OffsetDateTime.parse("1997-01-01T12:00:27.87+00:20").toInstant()
        annotate_check "Check that State is Outstanding"
        assert it[/State/] == "Outstanding"
        annotate_check "Check that Acknowledgement User Identifier is not set"
        assert it[/Acknowledgement User Identifier/] == null
        annotate_check "Check that Acknowledgement Time Stamp is not set"
        assert it[/Acknowledgement Time Stamp/] == null
        annotate_check "Check original Additional Text has been mapped correctly"
        assert it['Additional Text'] =~ /Everything is on fire!/
    }
    annotate_action "Send acknowledge alarm event from EMS simulator"
    emsSendEvents("""[
{
  "notificationType": "notifyAckStateChanged",
  "objectInstance": "IRPNetwork=ABCNetwork,Subnet=TN2,BSS=B5C0100",
  "eventTime": "1997-01-01T12:00:28.87+00:20",
  "systemDN": "DC=www.huawei.com , SubNetwork=1 , ManagementNode=1 , IRPAgent=1",
  "alarmId": "AMS:5654",
  "agentEntity": "oad_south",
  "ackUserId": "John Doe",
  "ackState": "Acknowledged",
  "customStringAttribute": "custom string value",
  "customListAttribute": [
    "custom value 1",
    "custom value 2",
    "custom value 3"
  ]
}
]""")
    annotate_action "Wait for the alarm to become Acknowledged in OC"
    shell($/wait_for_oc_content $$oc_1 'contains "State = Acknowledged"'/$)
    LibCheck.unpackOcAlarm(shell($/cat $$0.tmp | extract_alarms_from_oc/$).first()).tap {
        annotate_check "Check AO Event Time is still as in original alarm"
        // https://jira-pro.its.example.com:8443/browse/CMSVTP-6781
        // Event Time discrepancy between clear and acknowledge
        //assert it['Event Time'] ==
        //        java.time.OffsetDateTime.parse("1997-01-01T12:00:27.87+00:20").toInstant()
        assert it['Event Time'] ==
                java.time.OffsetDateTime.parse("1997-01-01T12:00:28.87+00:20").toInstant()
        annotate_check "Check that State is Acknowledged"
        assert it[/State/] == "Acknowledged"
        annotate_check "Check that Acknowledgement User Identifier is same as in up ack notification"
        // https://jira-pro.its.example.com:8443/browse/CMSVTP-6780
        // AHFM does not propagate Acknowledgement User Identifier and Acknowledgement Time Stamp in 3GPP alarms
        //assert it[/Acknowledgement User Identifier/] == "John Doe"
        assert it[/Acknowledgement User Identifier/] == '3GPP_Agent_User'
        annotate_check "Check that Acknowledgement Time Stamp is same as in up ack notification"
        // https://jira-pro.its.example.com:8443/browse/CMSVTP-6780
        // AHFM does not propagate Acknowledgement User Identifier and Acknowledgement Time Stamp in 3GPP alarms
        //assert it[/Acknowledgement Time Stamp/] ==
        //        java.time.OffsetDateTime.parse("1997-01-01T12:00:28.87+00:20").toInstant()
        assert (java.time.Instant.now().minusSeconds(15)).isBefore(it[/Acknowledgement Time Stamp/] as Instant)
        annotate_check "Check original Additional Text has not changed"
        assert it['Additional Text'] =~ /Everything is on fire!/
    }
    annotate_action "Send unacknowledge alarm event from EMS simulator"
    emsSendEvents("""[
{
  "notificationType": "notifyAckStateChanged",
  "objectInstance": "IRPNetwork=ABCNetwork,Subnet=TN2,BSS=B5C0100",
  "eventTime": "1997-01-01T12:00:29.87+00:20",
  "systemDN": "DC=www.huawei.com , SubNetwork=1 , ManagementNode=1 , IRPAgent=1",
  "alarmId": "AMS:5654",
  "agentEntity": "oad_south",
  "ackUserId": "Ivan Petrov",
  "ackState": "Unacknowledged",
  "customStringAttribute": "custom string value",
  "customListAttribute": [
    "custom value 1",
    "custom value 2",
    "custom value 3"
  ]
}
]""")
    annotate_action "Wait for the alarm to become Outstanding in OC"
    shell($/wait_for_oc_content $$oc_1 'contains "State = Outstanding"'/$)
    LibCheck.unpackOcAlarm(shell($/cat $$0.tmp | extract_alarms_from_oc/$).first()).tap {
        annotate_check "Check AO Event Time is still as in original alarm"
        // This is different for ack via directive and ack via event.
        // When ack via directive, Event Time does not change.
        //assert it['Event Time'] ==
        //        java.time.OffsetDateTime.parse("1997-01-01T12:00:27.87+00:20").toInstant()
        assert it['Event Time'] ==
                java.time.OffsetDateTime.parse("1997-01-01T12:00:29.87+00:20").toInstant()
        annotate_check "Check that State is Outstanding"
        assert it[/State/] == "Outstanding"
        annotate_check "Check that Acknowledgement User Identifier is same as in up unack notification"
        // https://jira-pro.its.example.com:8443/browse/CMSVTP-6780
        // AHFM does not propagate Acknowledgement User Identifier and Acknowledgement Time Stamp in 3GPP alarms
        //assert it[/Acknowledgement User Identifier/] == "Ivan Petrov"
        assert it[/Acknowledgement User Identifier/] == '3GPP_Agent_User'
        annotate_check "Check that Acknowledgement Time Stamp is same as in up unack notification"
        // https://jira-pro.its.example.com:8443/browse/CMSVTP-6780
        // AHFM does not propagate Acknowledgement User Identifier and Acknowledgement Time Stamp in 3GPP alarms
        //assert it[/Acknowledgement Time Stamp/] ==
        //        java.time.OffsetDateTime.parse("1997-01-01T12:00:29.87+00:20").toInstant()
        assert (Instant.now().minusSeconds(15)).isBefore(it[/Acknowledgement Time Stamp/] as Instant)
        annotate_check "Check original Additional Text has not changed"
        assert it['Additional Text'] =~ /Everything is on fire!/
    }
})
