import groovy.transform.CompileDynamic
import groovy.util.logging.Log4j2
import org.apache.commons.exec.OS
import org.apache.commons.exec.StreamPumper
import org.apache.commons.io.output.TeeOutputStream

import java.util.concurrent.ConcurrentHashMap

/**
 * Functions to execute commands with operating system.
 */
@Log4j2
@SuppressWarnings('ThreadLocalNotStaticFinal')
@SuppressWarnings('PrivateFieldCouldBeFinal')
@SuppressWarnings('FieldTypeRequired')
@SuppressWarnings('UnnecessaryDefInFieldDeclaration')
@SuppressWarnings('MethodReturnTypeRequired')
@SuppressWarnings('NoDef')
@SuppressWarnings('UnnecessaryDefInMethodDeclaration')
@SuppressWarnings('VariableTypeRequired')
@SuppressWarnings('MethodParameterTypeRequired')
@SuppressWarnings('AbcMetric')
@SuppressWarnings('MethodSize')
@SuppressWarnings('ParameterReassignment')
@SuppressWarnings('LineLength')
@SuppressWarnings('FileCreateTempFile')
@SuppressWarnings('SystemExit')
@CompileDynamic
class Exec {
    private static ThreadLocal<Boolean> acceptOkStorage = [initialValue: { true }] as ThreadLocal
    private static ThreadLocal<Boolean> acceptErrorStorage = [initialValue: { false }] as ThreadLocal
    private static ThreadLocal<Map<String, String>> envAddStorage = [initialValue: { [:] }] as ThreadLocal
    private static ThreadLocal<Map<String, String>> envOverrideStorage = [initialValue: { [:] }] as ThreadLocal
    private static ThreadLocal<Boolean> doNotWaitForOutputStorage = [initialValue: { false }] as ThreadLocal
    private static ThreadLocal<Boolean> asyncStorage = [initialValue: { false }] as ThreadLocal
    private static Map<Process, ByteArrayOutputStream> asyncOutStorage = new ConcurrentHashMap<>()
    private static ThreadLocal<Boolean> showCommandStorage = [initialValue: { true }] as ThreadLocal
    private static ThreadLocal<Boolean> showOutStorage = [initialValue: { true }] as ThreadLocal
    private static ThreadLocal<String> directoryStorage = [] as ThreadLocal
    private static ThreadLocal<Integer> lastExitCodeStorage = [initialValue: { 0 }] as ThreadLocal
    private static ThreadLocal<Process> lastProcessStorage = [initialValue: { 0 }] as ThreadLocal
    private static ThreadLocal<List<String>> prefixArgsStorage = [initialValue: { [] }] as ThreadLocal

    /**
     * New line characters.
     * The value is adjusted to the operating system we are run on.
     */
    public static final String NEW_LINE = System.lineSeparator()

    private static def measure = { String stage, Closure code ->
        long start = System.currentTimeMillis()
        code()
        long end = System.currentTimeMillis()
        log.debug "__ $stage took ${end - start} ms"
    }

    /**
     * Adjust environment variables with which commands will be run.
     * @param toOverride Variables that should substitute ones already defined.
     * @param toAdd Variables that should be added before ones already defined.
     * These variables will be overwritten by those that are already defined.
     * @param code Code to run.
     * @return Result of running {@code code}.
     */
    static def withEnv(Map<String, String> toOverride, Map<String, String> toAdd = [:], Closure code) {
        def oldAdd = envAddStorage.get()
        def oldOverride = envOverrideStorage.get()
        envAddStorage.set(toAdd + envAddStorage.get())
        envOverrideStorage.set(envOverrideStorage.get() + toOverride)
        try {
            code()
        }
        finally {
            envAddStorage.set(oldAdd)
            envOverrideStorage.set(oldOverride)
        }
    }
    /**
     * Execute specified command with operating system.
     * Do not wait for a process output and  streams STDOUT/STDERR of executed command to /dev/null.
     * Should be used if specified command creates background processes.
     * @param code Code to execute.
     */
    static void dontWait(Closure code) {
        Boolean oldDoNotWaitForOutput = doNotWaitForOutputStorage.get()
        doNotWaitForOutputStorage.set(true)
        try {
            code()
        }
        finally {
            doNotWaitForOutputStorage.set(oldDoNotWaitForOutput)
        }
    }
    /**
     * Execute specified command with operating system.
     * This function streams STDOUT/STDERR of executed command to our own STDOUT.
     * Waits for command to finish.
     * @param command Command to execute.
     * Can be either a space separated string or a list of individual strings.
     * The first element should be executable and the rest are arguments.
     * @param verbose {@code true} if should print what is being executed. This is default.
     * @return List of strings from out and err of executed command.
     * @throws AssertionError If command has returned unexpected exit code.
     * By default expected code is zero.
     * @see #expectError
     * @see #ignoreError
     */
    static List<String> exec(def command) {
        if (command instanceof String || command instanceof GString) {
            List<String> cmd = command.split(' ')
            command = cmd
        }
        if (prefixArgsStorage.get()) {
            command = prefixArgsStorage.get() + command
        }
        if (showCommandStorage.get()) {
            log.info "Executing: $command"
        }
        ByteArrayOutputStream captureStream = new ByteArrayOutputStream()
        OutputStream outputStream = showOutStorage.get() ? new TeeOutputStream(captureStream, System.out) : captureStream
        try {
            def newEnv = envAddStorage.get() + System.getenv() + envOverrideStorage.get()
            Process process
            lastProcessStorage.set(null)
            def commandLine = ([] + command) as String[]
            def environment = newEnv.collect { it.key + '=' + it.value } as String[]
            measure "## $command exec", {
                if (directoryStorage.get()) {
                    File workDir = new File(directoryStorage.get())
                    process = Runtime.runtime.exec(commandLine, environment, workDir)
                } else {
                    process = Runtime.runtime.exec(commandLine, environment)
                }
                lastProcessStorage.set(process)
            }
            if (asyncStorage.get()) {
                def outThread = new Thread(new StreamPumper(process.getInputStream(), outputStream))
                outThread.name = "Consumer for out of $command"
                outThread.daemon = true
                outThread.start()
                def errThread = new Thread(new StreamPumper(process.getErrorStream(), outputStream))
                errThread.name = "Consumer for err of $command"
                errThread.daemon = true
                errThread.start()
                asyncOutStorage.put(process, captureStream)
                log.info "------> Async process ${process.@pid} started for $command"
                return []
            }
            if (!doNotWaitForOutputStorage.get()) {
                measure "## $command waitForProcessOutput", {
                    // FIXME: this one can take up to 8 sec for some reason
                    // It's not really groovy dependent, same for commons-exec
                    // TODO: perhaps make version of exec that doesnt care about output?
                    process.waitForProcessOutput(outputStream, outputStream)
                }
            }
            measure "## $command waitFor", {
                lastExitCodeStorage.set(process.waitFor())
            }
            def okAndWaitForOk = lastExitCodeStorage.get() == 0 && acceptOkStorage.get()
            def errorAndWaitForError = lastExitCodeStorage.get() != 0 && acceptErrorStorage.get()
            assert okAndWaitForOk || errorAndWaitForError: "Unexpected exit code for $command: ${lastExitCodeStorage.get()}"
        } finally {
            outputStream.flush()
        }
        def result = captureStream.toString().split('\r\n')*.split('\n').flatten()
        result
    }

    /**
     * Execute specified SHELL command.
     * This function streams STDOUT/STDERR of executed command to our own STDOUT.
     * Waits for command to finish.
     * @param command Command to be executed.
     * Can be either a space separated string or a list of individual strings.
     * The first element should be executable and the rest are arguments.
     * @return List of strings from out and err of executed command.
     * @throws AssertionError If command has returned unexpected exit code.
     * By default expected code is zero.
     * @see #expectError
     * @see #ignoreError
     */
    static List<String> shell(String command) {
        File script = File.createTempFile('exec-', OS.isFamilyWindows() ? '.cmd' : '.sh', new File('.'))
        script.withPrintWriter { out ->
            if (OS.isFamilyWindows()) {
                out.println('@echo off')
            }
            if (doNotWaitForOutputStorage.get()) {
                out.print command
                out.println ' > /dev/null 2>&1'
            } else {
                out.println command
            }
        }
        if (showCommandStorage.get()) {
            log.info "Executing as shell script: ${prefixArgsStorage.get() ?: ''} $command"
        }
        script.setExecutable(true, false)
        def shell = OS.isFamilyWindows() ? [] : ['bash']
        try {
            return dontShowCommand {
                exec(
                        System.getenv()['test_case'] ?
                                [*shell, '-c', $/exec -a "${System.getenv()['test_case']}" ${script.absolutePath}/$] :
                                [*shell, script.absolutePath]
                )
            }
        } finally {
            script.delete()
        }
    }

    /**
     * Changes directory where to run commands.
     * @param newDirectory Directory where to run commands.
     * @param code Code to run.
     * @return Result of running {@code code}.
     * @throws AssertionError If command has returned unexpected exit code.
     * @see Exec#ignoreError
     * @see Exec#expectError
     */
    static List<String> inDir(String newDirectory, Closure code) {
        def old = directoryStorage.get()
        directoryStorage.set(newDirectory)
        try {
            return code()
        } finally {
            directoryStorage.set(old)
        }
    }

    /**
     * Ignores exit code of commands executed with operating system.
     * @param code Code to execute.
     * @return Result of running {@code code}.
     * @see #expectError
     */
    static def ignoreError(Closure code) {
        def oldAcceptOk = acceptOkStorage.get()
        def oldAcceptError = acceptErrorStorage.get()
        acceptOkStorage.set(true)
        acceptErrorStorage.set(true)
        try {
            return code()
        } finally {
            acceptOkStorage.set(oldAcceptOk)
            acceptErrorStorage.set(oldAcceptError)
        }
    }

    /**
     * Expects commands executed with operating system to exit with non-zero exit code.
     * @param code Code to execute.
     * @return Result of running {@code code}.
     * @throws AssertionError If command has returned zero exit code.
     * @see #ignoreError
     */
    static def expectError(Closure code) {
        def oldAcceptOk = acceptOkStorage.get()
        def oldAcceptError = acceptErrorStorage.get()
        acceptOkStorage.set(false)
        acceptErrorStorage.set(true)
        try {
            return code()
        } finally {
            acceptOkStorage.set(oldAcceptOk)
            acceptErrorStorage.set(oldAcceptError)
        }
    }

    // XXX: Consider to delete and replace with static import of System.exit function
    /**
     * Terminates the current process. The argument serves as a status code; by convention, a nonzero status code indicates abnormal termination.
     * @param statusCode exit status
     * @return Nothing.
     */
    static def exit(int statusCode) {
        System.exit(statusCode)
    }

    /**
     * Gets exit code of last executed process.
     * @return Exit code of last executed process or null if none.
     */
    static Integer getLastExitCode() {
        return lastExitCodeStorage.get()
    }

    /**
     * Gets last started process.
     * @return Last started process or null if none.
     */
    static Process getLastProcess() {
        lastProcessStorage.get()
    }

    /**
     * Makes commands run asynchronously.
     * @param code Code to execute.
     * @return Last started process.
     */
    static Process async(Closure code) {
        def old = asyncStorage.get()
        asyncStorage.set(true)
        try {
            code()
        } finally {
            asyncStorage.set(old)
        }
        getLastProcess()
    }

    /**
     * Kills tree of processes.
     * @param process Process to kill. Can be either Process or PID.
     */
    static void killTree(def process) {
        def pid = process instanceof Process ? process.@pid : process
        ignoreError {
            exec(['/usr/bin/kill', '-9', "$pid"])
            exec(['/usr/bin/pkill', '-9', '-P', "$pid"])
        }
    }

    /**
     * Gets output of asynchronous process.
     *
     * @param process Process whose output to return.
     * @return Process's output or null if process is unknown.
     */
    static String outOf(Process process) {
        asyncOutStorage.get(process)?.flush()
        asyncOutStorage.get(process)?.toString()
    }

    /**
     * Disables showing output of executed command.
     * @param code Code to execute.
     * @return Result of running {@code code}.
     */
    static def dontShowOut(Closure code) {
        def old = showOutStorage.get()
        showOutStorage.set(false)
        try {
            return code()
        } finally {
            showOutStorage.set(old)
        }
    }

    /**
     * Disables showing executed command line.
     * @param code Code to execute.
     * @return Result of running {@code code}.
     */
    static def dontShowCommand(Closure code) {
        def old = showCommandStorage.get()
        showCommandStorage.set(false)
        try {
            return code()
        } finally {
            showCommandStorage.set(old)
        }
    }

    /**
     * Makes commands being executed as sudo.
     * @param code Code to execute.
     * @return Result of running code.
     */
    static def sudo(Closure code) {
        def old = prefixArgsStorage.get()
        prefixArgsStorage.set(old + ['sudo'])
        try {
            return code()
        } finally {
            prefixArgsStorage.set(old)
        }
    }

    /**
     * Environment variables on the time when simulator has started.
     */
    final static Map<String, String> ENV = Collections.unmodifiableMap(System.getenv().with { withJunk ->
        Set<String> junkStarts = [
                'BASH_',
                'KDE',
                'LS_',
                'KONSOLE_',
                'PERL_',
                'PKG_',
                'QT',
                'SDKMAN_',
                'SSH_',
                'XDG_',
        ]
        withJunk.findAll { k, v -> !junkStarts.any { junk -> k.startsWith(junk) } }
                .sort { a, b -> a.key.toLowerCase() <=> b.key.toLowerCase() }
    })

    /**
     * Evaluate expression with shell.
     * Neither result not command will be printed out instead result will be returned.
     * @param expression Shell expression to evaluate. Like $0.tmp
     * @return What expression has evaluated to.
     */
    static String shellEval(String expression) {
        dontShowCommand { dontShowOut { shell("echo $expression").join('\n') } }
    }

}
