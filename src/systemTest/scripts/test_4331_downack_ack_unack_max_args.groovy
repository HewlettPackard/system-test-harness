import org.apache.camel.Exchange
import org.apache.camel.Expression
import org.apache.camel.http.common.HttpMethods

import java.time.Instant

import static Exec.ENV
import static Exec.shell

new Simulator()({
    annotate_action('Configure EMS simulator to respond to a request to acknowledgment alarm and indicate operation was a success')
    emsDownAckMock.resultWaitTime = 10000
    emsDownAckMock.expectedMessageCount(1)
    emsDownAckMock.returnReplyBody({ Exchange exchange, Class type ->
        null
    } as Expression)
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
    long aoIdentifier = LibCheck.unpackOcAlarm(LibCheck.waitOcAlarms().first()).with {
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
        it['Identifier'] as Long
    }
    annotate_action "Execute Acknowledge directive"
    shell($/$$manage acknowledge oper ${ENV['oc_1']} alarm ${aoIdentifier} UserId='John Doe'/$)

    annotate_action "Wait for the alarm to become Acknowledged in OC"
    shell($/wait_for_oc_content $$oc_1 'contains "State = Acknowledged"'/$)
    LibCheck.unpackOcAlarm(shell($/cat $$0.tmp | extract_alarms_from_oc/$).first()).tap {
        annotate_check "Check that AO that became acknowledged is the same which was requested to be acknowledged"
        assert it['Identifier'] == aoIdentifier
        annotate_check "Check AO Event Time is still as in original alarm"
        assert it['Event Time'] ==
                java.time.OffsetDateTime.parse("1997-01-01T12:00:27.87+00:20").toInstant()
        annotate_check "Check that State is Acknowledged"
        assert it[/State/] == /Acknowledged/
        annotate_check "Check that Acknowledgement User Identifier is set to the values specified in userId argument"
        assert it[/Acknowledgement User Identifier/] == 'John Doe'
        annotate_check "Check that Acknowledgement Time Stamp is set around now rather as no Timestamp argument is specified"
        assert (Instant.now().minusSeconds(15)).isBefore(it[/Acknowledgement Time Stamp/] as Instant)
        annotate_check "Check original Additional Text has not changed"
        assert it['Additional Text'] =~ /Everything is on fire!/
    }

    annotate_action "Check EMS simulator has received one request to acknowledged alarm"
    emsDownAckMock.assertIsSatisfied()
    assert emsDownAckMock.exchanges.size() == 1
    emsDownAckMock.assertExchangeReceived(0).tap {
        assert it.message.headers[HTTP_METHOD] == HttpMethods.PATCH.name()
        assert parsePath(it) == '/tmb/10/alarms/AMS:5654'
        it.message.getMandatoryBody(Map).tap {
            assert it.size() == 3
            assert it['ackSystemId'] == "Platform"
            assert it['ackstate'] == "acknowledged"
            assert it['ackUserId'] == "John Doe"
        }
    }

    annotate_action('Configure EMS simulator to respond to a request to unacknowledgment alarm and indicate operation was a success')
    emsDownAckMock.reset()
    emsDownAckMock.resultWaitTime = 10000
    emsDownAckMock.expectedMessageCount(1)
    emsDownAckMock.returnReplyBody({ Exchange exchange, Class type ->
        null
    } as Expression)

    annotate_action "Execute Unacknowledge directive"
    shell($/$$manage unacknowledge oper ${ENV['oc_1']} alarm ${aoIdentifier} UserId='John Carter'/$)

    annotate_action "Wait for the alarm to become Outstanding in OC"
    shell($/wait_for_oc_content $$oc_1 'contains "State = Outstanding"'/$)
    LibCheck.unpackOcAlarm(shell($/cat $$0.tmp | extract_alarms_from_oc/$).first()).tap {
        annotate_check "Check that AO that became acknowledged is the same which was requested to be acknowledged"
        assert it['Identifier'] == aoIdentifier
        annotate_check "Check AO Event Time is still as in original alarm"
        assert it['Event Time'] ==
                java.time.OffsetDateTime.parse("1997-01-01T12:00:27.87+00:20").toInstant()
        annotate_check "Check that State is Outstanding"
        assert it[/State/] == "Outstanding"
        annotate_check "Check that Acknowledgement User Identifier is same as specified in UserId argument"
        assert it[/Acknowledgement User Identifier/] == "John Carter"
        annotate_check "Check that Acknowledgement Time Stamp has become around time when alarm has request to unacknowledge"
        assert (Instant.now().minusSeconds(15)).isBefore(it[/Acknowledgement Time Stamp/] as Instant)
        annotate_check "Check original Additional Text has not changed"
        assert it['Additional Text'] =~ /Everything is on fire!/
    }

    annotate_action "Check EMS simulator has received one request to acknowledged alarm"
    emsDownAckMock.assertIsSatisfied()
    assert emsDownAckMock.exchanges.size() == 1
    emsDownAckMock.assertExchangeReceived(0).tap {
        assert it.message.headers[HTTP_METHOD] == HttpMethods.PATCH.name()
        assert parsePath(it) == '/tmb/10/alarms/AMS:5654'
        it.message.getMandatoryBody(Map).tap {
            assert it.size() == 3
            assert it['ackSystemId'] == "Platform"
            assert it['ackstate'] == "unacknowledged"
            assert it['ackUserId'] == "John Carter"
        }
    }
})
