import groovy.transform.CompileStatic
import groovy.util.logging.Log4j2

import java.time.Duration
import java.time.Instant
import java.time.ZoneId
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter
import java.time.format.DateTimeFormatterBuilder
import java.util.function.Function
import java.util.regex.Matcher
import java.util.regex.Pattern
import java.util.stream.Collectors

import static Exec.shell

/**
 * Library of generic test functions.
 */
@Log4j2
@CompileStatic
class LibCheck {

    /**
     * Asserts that a string contains all patterns.
     * @param source String where to check presence of patterns.
     * @param patterns Patterns to check.
     */
    static void assertAllPatternsFound(String source, List<String> patterns) {
        patterns.each { pattern ->
            assert (source =~ pattern).find(): "Pattern $pattern not found in $source"
        }
    }

    /**
     * Asserts that a string contains all patterns.
     * @param source String where to check presence of patterns.
     * @param patterns Patterns to check. Keys are explanations for the patterns and values are patterns themselves.
     */
    static void assertAllPatternsFound(String source, Map<String, Pattern> patterns) {
        patterns.each { name, pattern ->
            assert pattern.matcher(source).find(): "Check failed: $name: Pattern $pattern not found in $source"
        }
    }

    /**
     * Asserts that all patterns are found within list of strings.
     * @param source List of strings to be checked.
     * @param patterns Patterns to check.
     */
    static void assertAllPatternsFound(List<String> source, List<String> patterns) {
        assertAllPatternsFound(source.join('\n'), patterns)
    }

    /**
     * Wait TeMIP operation context to get specified number of alarms.
     * @param ocName Name of OC to monitor. By default, refers to oc_1 variable.
     * @param expectedCount Number of alarms to wait to. By default, 1.
     * @param confidence Desired confidence for a number of alarms. By default, not set and will use harness default.
     * @return List of strings where each line is an alarm as per extract_alarms_from_oc. Means line
     * endings were replaced with triple at-sign and attributes are names as per TeMIP dictionary.
     * Note that FCL PM will wrap all strings in double quotes and sets in curly braces.
     * Enums are not wrapped in quotes.
     */
    static List<String> waitOcAlarms(String ocName = Exec.ENV['oc_1'],
                                     Integer expectedCount = 1,
                                     Integer confidence = null) {
        String confidenceAddon = confidence != null ? "confidence=$confidence" : ''
        shell($/$confidenceAddon wait_for_oc_content $ocName 'test $$count -eq $expectedCount'/$)
        shell($/cat $$0.tmp | extract_alarms_from_oc/$)
    }

    /**
     * Parse alarm compressed by extract_alarms_from_oc into map of attributes.
     * @param packedAlarm Alarm compressed by extract_alarms_from_oc.
     * @return Map of alarm attributes. Attribute names are as per TeMIP dictionary.
     * Strings have double quotes removed. False/True is represented as Boolean.
     * Numbers are represented as BigDecimal. Sets are parsed as List.
     * Records are not parsed and stay as strings.
     * Dates are parsed into Instant.
     */
    static Map<String, ?> unpackOcAlarm(String packedAlarm) {
        String fieldSeparator = ' @@@ '
        Matcher fieldMatcher = packedAlarm =~ /${fieldSeparator}[\s\w\d]+ = /
        List<Integer> fieldsStarts = []
        while (fieldMatcher.find()) {
            fieldsStarts << fieldMatcher.start()
        }
        List<String> nameValuePairs = []
        fieldsStarts.eachWithIndex { int fieldStart, int fieldIndex ->
            nameValuePairs << ((fieldIndex == 0) ? packedAlarm[0..fieldStart]
                    : packedAlarm[fieldsStarts[fieldIndex - 1] + fieldSeparator.length()..fieldStart - 1])
        }
        nameValuePairs << packedAlarm[fieldsStarts.last() + fieldSeparator.length()..-1]
        return nameValuePairs
                *.split(' = ', 2)
                .stream()
                .map({ String[] it -> [(it[0]), it[1..-1].join('').trim()] } as Function<String[], List<String>>)
                .collect(Collectors.toMap(
                        { List<String> it -> it.first() } as Function<List<String>, String>,
                        { List<String> it ->
                            String stringValue = String.cast(it.last()).replaceAll(' #@#@ ', '\n')
                            parseOcValue(stringValue)
                        } as Function<List<String>, Object>,
                ))
    }

    /**
     * Parses values shown by manage for OC AO attribute into a Java type.
     * @param stringValue Value shown by manage.
     * @return As per following rules:
     *   <ul>
     *     <li>BigDecimal if value is a number</li>
     *     <li>String (with quotes stripped at beginning and end)</li>
     *     <li>List&lt;String&gt; if set of records</li>
     *     <li>Content of set as String if some other set</li>
     *     <li>Instance if date/time</li>
     *     <li>Boolean if boolean</li>
     *     <li>String if cannot recognize</li>
     *   </ul>
     */
    static Object parseOcValue(String stringValue) {
        Object resultValue
        if (stringValue.startsWith(/{/) && stringValue.endsWith(/}/)) {
            String unwrapped = stringValue[1..-2].trim().replaceAll('\n', ' ')
            boolean probablyRecord = unwrapped.startsWith(/(/)
            resultValue = probablyRecord ? unwrapped : (unwrapped.split(/, /) as List)
        } else if (stringValue.startsWith(/"/) && stringValue.endsWith(/"/)) {
            resultValue = stringValue - ~/^"/ - ~/"$/
        } else if (stringValue.isNumber()) {
            resultValue = stringValue as BigDecimal
        } else if (stringValue =~ /\d\d\d\d-\d\d-\d\d-\d\d:\d\d:\d\d\.\d\d\dI-----/) {
            resultValue = Instant.from(new DateTimeFormatterBuilder()
                    .parseCaseInsensitive()
                    .append(DateTimeFormatter.ISO_LOCAL_DATE)
                    .appendLiteral('-')
                    .append(DateTimeFormatter.ISO_LOCAL_TIME)
                    .appendLiteral('I-----')
                    .toFormatter()
                    .withZone(ZoneId.of(ZoneOffset.UTC.id))
                    .parse(stringValue))
        } else if (stringValue == 'False') {
            resultValue = false
        } else if (stringValue == 'True') {
            resultValue = true
        } else {
            resultValue = stringValue
        }
        return resultValue
    }

    /**
     * Parses value of alarm comment field (TeMIP set of records) into a Java type.
     *
     * Commas are not supported in fields values.
     *
     * @param stringValue Value shown by manage.
     * @return List of maps, where each map is a parsed TeMIP record.
     * Value of each TeMIP record field is parsed as per {@see #parseOcValue}.
     */
    @SuppressWarnings('DuplicateNumberLiteral') // It would prefer to avoid to introducing constants for reqexp groups
    static List<Map<String, Object>> parseAlarmComments(String stringValue) {
        Matcher matcherComments = stringValue =~ /\(([^)]+)\)/
        (0..<matcherComments.count).collect { int commentIdx ->
            String comment = List.cast(matcherComments[commentIdx])[1]
            comment = comment.trim()
            Matcher matcherFields = comment =~ /([^ ,].*?)\s=\s([^,]+)/
            (0..<matcherFields.count).collectEntries { int fieldIdx ->
                String field = List.cast(matcherFields[fieldIdx])[1]
                String value = List.cast(matcherFields[fieldIdx])[2]
                [field, parseOcValue(value)]
            }
        } as List<Map<String, Object>>
    }

    /**
     * Gets tail of the file.
     * @param file Path to file.
     * @param start Beginning from which to read file (inclusive).
     * @return Tail of the file from the specified position.
     * @throws IOException If file cannot be read.
     */
    static String tail(String file, long start) throws IOException {
        new RandomAccessFile(file, 'r').withCloseable {
            it.seek(start)
            byte[] content = new byte[it.length() - start]
            it.readFully(content)
            new String(content)
        }
    }

    /**
     * Check if specified time is somewhere around now.
     * @param time Time to check.
     * @return true if specified time is somewhere around now.
     */
    static boolean aroundNow(Instant time) {
        Instant now = Instant.now()
        Duration maxLag = Duration.ofMinutes(10)
        time > (now - maxLag) && time < (now + maxLag)
    }

}
