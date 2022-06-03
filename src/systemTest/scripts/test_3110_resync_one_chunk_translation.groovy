import org.apache.camel.Exchange
import org.apache.camel.Expression

import java.time.OffsetDateTime

import static Exec.ENV
import static Exec.shell

new Simulator()({
    annotate_action "Configure EMS simulator to expect single request and respond with a batch of never acknowledged alarms"
    emsResyncMock.resultWaitTime = 10000
    emsResyncMock.expectedMessageCount(1)
    emsResyncMock.returnReplyBody({ Exchange exchange, Class type ->
        """
{
  "data": [
    {
      "notificationType": "notifyResyncAlarm",
      "alarmType": "CommunicationsAlarm",
      "objectClass": "ManagedElement",
      "objectInstance": "deviceID=1,sourceID=A,name=RPD_ISIS_ADJUP,elementType=NodeB",
      "notificationId": 3,
      "correlatedNotifications": [
        1,
        2
      ],
      "eventTime": "2018-11-13T20:20:39+00:00",
      "systemDN": "DC=www.huawei.com , SubNetwork=1 , ManagementNode=1 , IRPAgent=1",
      "alarmId": "AMS:5654",
      "agentEntity": "ems_1",
      "probableCause": "a-bis to bts interface failure",
      "perceivedSeverity": "Critical",
      "specificProblem": [
        "example specific problem 1"
      ],
      "additionalText": "NeType: BSC6910 UMTS| NeLocation: | vendor: | neName: 10.141.115.225| alarmName: OMU Time Synchronization Abnormity| alarmLocation: Subrack No.=0, Slot No.=5, SNTP Server Information=NULL| appendInfo: ",
      "comments": [
        {
          "commentTime": "2018-11-13T20:20:39+00:00",
          "commentText": "Seems like same situation as last time",
          "commentUserId": "John Doe"
        }
      ],
      "siteLocation": "Montreal",
      "regionLocation": "Bavaria",
      "vendorName": "Hewlett Packard Enterprise",
      "technologyDomain": "Mobile",
      "equipmentModel": "EKS 573",
      "plannedOutageIndication": false
    },
    {
      "notificationType": "notifyResyncAlarm",
      "alarmType": "CommunicationsAlarm",
      "objectClass": "ManagedElement",
      "objectInstance": "deviceID=3,sourceID=C,sourceIP=192.168.0.1,elementType=NodeB",
      "notificationId": 4,
      "correlatedNotifications": [
        1,
        2,
        3
      ],
      "eventTime": "2018-11-13T20:20:39+00:00",
      "systemDN": "DC=www.huawei.com , SubNetwork=1 , ManagementNode=1 , IRPAgent=1",
      "alarmId": "AMS:5655",
      "agentEntity": "ems_1",
      "probableCause": "a-bis to bts interface failure",
      "perceivedSeverity": "Minor",
      "specificProblem": [
        "example specific problem 1",
        "example specific problem 2"
      ],
      "additionalText": "NeType: BSC6910 UMTS| NeLocation: | vendor: | neName: 10.141.115.225| alarmName: OMU Time Synchronization Abnormity| alarmLocation: Subrack No.=0, Slot No.=5, SNTP Server Information=NULL| appendInfo: ",
      "comments": [
        {
          "commentTime": "2018-11-13T20:20:39+00:00",
          "commentText": "Seems like same situation as last time",
          "commentUserId": "John Doe"
        }
      ],
      "siteLocation": "Montreal",
      "regionLocation": "Bavaria",
      "vendorName": "Hewlett Packard Enterprise",
      "technologyDomain": "Mobile",
      "equipmentModel": "EKS 573",
      "plannedOutageIndication": false
    }
  ]
}
"""
    } as Expression)
    // When
    annotate_action "Initiate OC resynchronization"
    shell('$manage resynchronization oper $oc_1')
    // Then
    shell($/$$manage show oper ${ENV['oc_1']} alarm \* all attr | extract_alarms_from_oc | perl -W -pe 's/ #@#@ / /g'/$).tap { alarms ->
        annotate_check "Check all AO were created in OC"
        assert alarms.size() == 2
        annotate_check "Check first alarm is mapped correctly"
        LibCheck.unpackOcAlarm(alarms.find { it.contains(/AMS:5654/) }).tap {
            annotate_check "Check mandatory Agent Alarm Identifier has been mapped correctly"
            assert it[/Agent Alarm Identifier/] == /AMS:5654/
            annotate_check "Check mandatory Agent Entity has been mapped correctly"
            assert it[/Agent Entity/] ==~ /${ENV['gc_1']} .*:\.${ENV['ems_1']}/
            annotate_check "Check mandatory Alarm Type has been mapped correctly"
            assert it[/Alarm Type/] == /CommunicationsAlarm/
            annotate_check "Check mandatory Managed Object Identifier has been mapped correctly"
            assert it[/Managed Object/] ==~ /${ENV['gc_1']} .*:\.${ENV['ems_1']} ${ENV['cc_1']} "\{1,A,RPD_ISIS_ADJ,NodeB}"/
            annotate_check "Check mandatory Perceived Severity has been mapped correctly"
            assert it[/Perceived Severity/] == /Critical/
            annotate_check "Check mandatory Probable Cause has been mapped correctly"
            assert it[/Probable Cause/] == /A-bis to BTS interface failure/
            annotate_check "Check optional Notification Identifier has been mapped correctly"
            assert it[/Notification Identifier/] == 3
            annotate_check "Check optional Correl Notif Info has been mapped correctly"
            assert it[/Correl Notif Info/] == /( correlatedNotification = { 1, 2 } )/
            annotate_check "Check mandatory Original Event Time has been mapped correctly"
            assert it[/Original Event Time/] == OffsetDateTime.parse(/2018-11-13T20:20:39.000Z/).toInstant()
            annotate_check "Check optional Specific Problems has been mapped correctly"
            assert it[/Specific Problems/] == [/example specific problem 1/]
            annotate_check "Check optional Additional Text has been mapped correctly"
            assert it[/Additional Text/] =~ /NeType: BSC6910 UMTS| NeLocation: | vendor: | neName: 10.141.115.225| alarmName: OMU Time Synchronization Abnormity| alarmLocation: Subrack No.=0, Slot No.=5, SNTP Server Information=NULL| appendInfo: "/
            annotate_check "Check Additional Text contains enter time stamp"
            assert it["Additional Text"] =~ /[Aa]dapter.*enter.*\d/
            annotate_check "Check Additional Text contains exit time stamp"
            assert it["Additional Text"] =~ /[Aa]dapter.*exit.*\d/
            annotate_check "Check optional Equipment Type has been mapped correctly"
            assert it[/Equipment Type/] == /ManagedElement/
            annotate_check "Check optional Site Location has been mapped correctly"
            assert it[/Site Location/] == /Montreal/
            annotate_check "Check optional Region Location has been mapped correctly"
            assert it[/Region Location/] == /Bavaria/
            annotate_check "Check optional Vendor Name has been mapped correctly"
            assert it[/Vendor Name/] == /Hewlett Packard Enterprise/
            annotate_check "Check optional Technology Domain has been mapped correctly"
            assert it[/Technology Domain/] == /Mobile/
            annotate_check "Check optional Equipment Model has been mapped correctly"
            assert it[/Equipment Model/] == /EKS 573/
            annotate_check "Check optional Outage Flag has been mapped correctly"
            assert it[/Outage Flag/] == false
            annotate_check "Check that State is Outstanding"
            assert it[/State/] == "Outstanding"
            annotate_check "Check that Acknowledgement User Identifier is not set"
            assert it[/Acknowledgement User Identifier/] == null
            annotate_check "Check that Acknowledgement Time Stamp is not set"
            assert it[/Acknowledgement Time Stamp/] == null
        }
        annotate_check "Check second alarm is mapped correctly"
        LibCheck.unpackOcAlarm(alarms.find { it.contains(/AMS:5655/) }).tap {
            annotate_check "Check mandatory Agent Alarm Identifier has been mapped correctly"
            assert it[/Agent Alarm Identifier/] == /AMS:5655/
            annotate_check "Check mandatory Agent Entity has been mapped correctly"
            assert it[/Agent Entity/] ==~ /${ENV['gc_1']} .*:\.${ENV['ems_1']}/
            annotate_check "Check mandatory Alarm Type has been mapped correctly"
            assert it[/Alarm Type/] == /CommunicationsAlarm/
            annotate_check "Check mandatory Managed Object Identifier has been mapped correctly"
            assert it[/Managed Object/] ==~ /${ENV['gc_1']} .*:\.${ENV['ems_1']} ${ENV['cc_1']} "\{3,C,192.168.0.1,NodeB}"/
            annotate_check "Check mandatory Perceived Severity has been mapped correctly"
            assert it[/Perceived Severity/] == /Minor/
            annotate_check "Check mandatory Probable Cause has been mapped correctly"
            assert it[/Probable Cause/] == /A-bis to BTS interface failure/
            annotate_check "Check optional Notification Identifier has been mapped correctly"
            assert it[/Notification Identifier/] == 4
            annotate_check "Check optional Correl Notif Info has been mapped correctly"
            assert it[/Correl Notif Info/] == /( correlatedNotification = { 1, 2, 3 } )/
            annotate_check "Check mandatory Original Event Time has been mapped correctly"
            assert it[/Original Event Time/] == OffsetDateTime.parse(/2018-11-13T20:20:39.000Z/).toInstant()
            annotate_check "Check optional Specific Problems has been mapped correctly"
            assert it[/Specific Problems/] == [
                    /example specific problem 1/,
                    /example specific problem 2/,
            ]
            annotate_check "Check optional Additional Text has been mapped correctly"
            assert it[/Additional Text/] =~ /NeType: BSC6910 UMTS| NeLocation: | vendor: | neName: 10.141.115.225| alarmName: OMU Time Synchronization Abnormity| alarmLocation: Subrack No.=0, Slot No.=5, SNTP Server Information=NULL| appendInfo: "/
            annotate_check "Check Additional Text contains enter time stamp"
            assert it["Additional Text"] =~ /[Aa]dapter.*enter.*\d/
            annotate_check "Check Additional Text contains exit time stamp"
            assert it["Additional Text"] =~ /[Aa]dapter.*exit.*\d/
            annotate_check "Check optional Equipment Type has been mapped correctly"
            assert it[/Equipment Type/] == /ManagedElement/
            annotate_check "Check optional Site Location has been mapped correctly"
            assert it[/Site Location/] == /Montreal/
            annotate_check "Check optional Region Location has been mapped correctly"
            assert it[/Region Location/] == /Bavaria/
            annotate_check "Check optional Vendor Name has been mapped correctly"
            assert it[/Vendor Name/] == /Hewlett Packard Enterprise/
            annotate_check "Check optional Technology Domain has been mapped correctly"
            assert it[/Technology Domain/] == /Mobile/
            annotate_check "Check optional Equipment Model has been mapped correctly"
            assert it[/Equipment Model/] == /EKS 573/
            annotate_check "Check optional Outage Flag has been mapped correctly"
            assert it[/Outage Flag/] == false
            annotate_check "Check that State is Outstanding"
            assert it[/State/] == "Outstanding"
            annotate_check "Check that Acknowledgement User Identifier is not set"
            assert it[/Acknowledgement User Identifier/] == null
            annotate_check "Check that Acknowledgement Time Stamp is not set"
            assert it[/Acknowledgement Time Stamp/] == null
        }
    }
})
