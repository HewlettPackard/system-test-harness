import java.time.OffsetDateTime

new Simulator()({
    annotate_action "Send raise alarm notification for never acknowledged alarm from EMS simulator"
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
    annotate_check "Check that AO was created in OC with correct attribute values"
    LibCheck.unpackOcAlarm(LibCheck.waitOcAlarms().first()).tap {
        annotate_check "Check mandatory Agent Alarm Identifier has been mapped correctly"
        assert it['Agent Alarm Identifier'] == "AMS:5654"
        annotate_check "Check mandatory Agent Entity has been mapped correctly"
        assert it['Agent Entity'] =~ /${Exec.ENV['gc_1']} .*:\.${Exec.ENV['ems_1']}/
        annotate_check "Check mandatory Alarm Type has been mapped correctly"
        assert it['Alarm Type'] == 'CommunicationsAlarm'
        annotate_check "Check mandatory Managed Object Identifier has been mapped correctly"
        assert it['Managed Object'] =~
                /${Exec.ENV['gc_1']} .*:\.${Exec.ENV['ems_1']} / +
                /${Exec.ENV['cc_1']} "\{3,C,192.168.0.1,NodeB\}"/
        annotate_check "Check mandatory Perceived Severity has been mapped correctly"
        assert it['Perceived Severity'] == 'Critical'
        annotate_check "Check mandatory Probable Cause has been mapped correctly"
        assert it['Probable Cause'] == 'Fire'
        annotate_check "Check optional Notification Identifier has been mapped correctly"
        assert it['Notification Identifier'] == 123
        annotate_check "Check optional Correl Notif Info has been mapped correctly"
        assert it['Correl Notif Info'] == "( correlatedNotification = { 1, 2 } )"
        annotate_check "Check mandatory Original Event Time has been mapped correctly"
        assert it['Original Event Time'] ==
                OffsetDateTime.parse("1997-01-01T11:40:27.870Z").toInstant()
        annotate_check "Check optional Specific Problems has been mapped correctly"
        assert it['Specific Problems'] == ['example specific problem 1']
        annotate_check "Check optional Additional Text has been mapped correctly"
        assert it['Additional Text'] =~ /Everything is on fire!/
        annotate_check "Check Additional Text contains enter time stamp"
        assert it["Additional Text"] =~ /[Aa]dapter.*enter.*\d/
        annotate_check "Check Additional Text contains exit time stamp"
        assert it["Additional Text"] =~ /[Aa]dapter.*exit.*\d/
        annotate_check "Check that State is Outstanding"
        assert it[/State/] == "Outstanding"
        annotate_check "Check that Acknowledgement User Identifier is not set"
        assert it[/Acknowledgement User Identifier/] == null
        annotate_check "Check that Acknowledgement Time Stamp is not set"
        assert it[/Acknowledgement Time Stamp/] == null
        annotate_check "Check optional Equipment Type has been mapped correctly"
        assert it['Equipment Type'] == "OT_PHYSICAL_TERMINATION_POINT"
        annotate_check "Check optional Site Location has been mapped correctly"
        assert it['Site Location'] == "Lindau"
        annotate_check "Check optional Region Location has been mapped correctly"
        assert it['Region Location'] == "Bavaria"
        annotate_check "Check optional Vendor Name has been mapped correctly"
        assert it['Vendor Name'] == "Hewlett Packard Enterprise"
        annotate_check "Check optional Technology Domain has been mapped correctly"
        assert it['Technology Domain'] == "Mobile"
        annotate_check "Check optional Equipment Model has been mapped correctly"
        assert it['Equipment Model'] == "MNM 3000"
        annotate_check "Check optional Outage Flag has been mapped correctly"
        assert it['Outage Flag'] == false
    }
})
