import org.apache.camel.Exchange
import org.apache.camel.Expression

import java.util.regex.Matcher

import static Exec.ENV
import static Exec.shell

final int alarmsCount = 3

new Simulator()({
    // Given
    annotate_action "Start simulator that will answer on getAlarmList directive with 4 chunks: first one is empty and each next carries a single alarm"
    emsResyncMock.resultWaitTime = 10000
    emsResyncMock.expectedMessageCount(4)
    emsResyncMock.returnReplyBody({ Exchange exchange, Class type ->
        try {
            Map<String, String> query = parseQueryParams(exchange)
            if (query['continuePreviousRequest'] != 'true') {
                return [
                        hasMore : true,
                        iterator: "0 of $alarmsCount",
                ]
            }
            String iterator = query['iterator']
            assert iterator
            Matcher matcher = iterator =~ /(\d+) of (\d+)/
            assert matcher.matches()
            int current = matcher.group(1) as int
            int end = matcher.group(2) as int
            current++
            Map<String, Object> reply = [
                    data: [
                            [
                                    "notificationType" : "notifyResyncAlarm",
                                    "alarmType"        : "CommunicationsAlarm",
                                    "objectClass"      : "ManagedElement",
                                    "objectInstance"   : "GsmCell=740",
                                    "notificationId"   : current,
                                    "eventTime"        : "2018-11-13T20:20:39.200+00:00",
                                    "alarmId"          : "$current",
                                    "agentEntity"      : "ems_1",
                                    "probableCause"    : "a-bis to bts interface failure",
                                    "perceivedSeverity": "Minor",
                            ],
                    ],
            ]
            if (current < end) {
                reply['hasMore'] = true
                reply['iterator'] = "$current of $end"
            }
            reply
        } catch (Throwable t) {
            routeConfigLog.error("Was an error in simulator", t)
            throw t
        }
    } as Expression)
    // When
    annotate_action "Initiate OC resynchronization"
    shell('$manage resynchronization oper $oc_1')
    // Then
    shell($/$$manage show oper ${ENV['oc_1']} alarm \* all attr | extract_alarms_from_oc/$).tap { alarms ->
        annotate_check "Check that all 3 AO have been created in OC"
        assert alarms.size() == 3
        annotate_check "Check that AOs have been mapped from corresponding active alarms"
        (1..alarmsCount).each { index ->
            assert alarms.find { it.contains(/Agent Alarm Identifier = "$index"/) }
        }
    }
})
