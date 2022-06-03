static List<Integer> zeroedList(int size) {
    List<Integer> result = new ArrayList<Integer>(size)
    (0..<size).each { result << 0 }
    result
}

assert zeroedList(5).size() == 5 && zeroedList(5).every { it == 0 }

File dir = new File(args[0])
assert dir.exists()
String fileName = args[1]
String additionalIgnores = args.size() > 2 ? args[2] : ''

Map<String, List<Integer>> usage = [:]
List<String> leaks = []

List<String> ignores = [
        /java.*/, /* Don't care for pure Java API, either our or some open source class must be leaked. */
        /\[.*/, /* Don't care for pure Java API, either our or some open source class must be leaked. */
        /com.codahale.metrics.*/, /* Metrics have a time window. */
        /.*[Tt]hread[Ll]ocal.*/, /* Thread local things aren't really a leak. */
        /org.apache.logging.*/, /* Log4j does some caching and it is highly unlikely it leaks. */
]

ignores += additionalIgnores.tokenize(',')

println "Ignores: $ignores"

int filesLoaded = 0
List<File> dumps = dir.listFiles().findAll { it.name.startsWith(fileName) }.sort { a, b -> a.name <=> b.name }
assert dumps
dumps.eachWithIndex { inputFile, dumpIndex ->
    filesLoaded++
    inputFile.withReader { input ->
        String line
        while ((line = input.readLine()) != null) {
            def (className, count) = line.split("\t")
            if (!usage[className as String]) {
                usage[className as String] = zeroedList(dumps.size())
            }
            usage[className as String][dumpIndex] = Integer.parseInt(count as String)
        }
    }
}
assert usage
usage.each { className, counts ->
    List<Integer> deltas = zeroedList(dumps.size() - 1)
    (0..<deltas.size()).each { index ->
        deltas[index] = counts[index + 1] - counts[index]
    }
    if (deltas.every { it > 0 }) {
        leaks << className
    }
}
ignores.each { ignore ->
    leaks.removeAll { leak ->
        boolean matches = leak ==~ ignore
        if (matches) {
            println "Ignoring $leak because it matches $ignore"
        }
        matches
    }
}
leaks.each { className ->
    println "Ever growing stats for $className: ${usage[className].join(", ")}"
}
assert !leaks
