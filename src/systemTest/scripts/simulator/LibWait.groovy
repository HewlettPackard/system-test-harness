import groovy.transform.CompileStatic
import groovy.util.logging.Log4j2

import javax.annotation.Nonnull
import javax.annotation.Nullable
import java.time.Duration
import java.time.Instant
import java.util.concurrent.TimeoutException

/**
 * Utilities to wait for a condition to happen.
 */
@Log4j2
@CompileStatic
class LibWait {

    /**
     * Waits for a condition.
     * @param condition Code that when evaluates to true then waiting finishes.
     * @param timeout Maximum duration to wait.
     * @param confidence null to stop waiting after
     * condition observed for a first time,
     * {@link Duration#ZERO} to sleep before
     * checking for a condition again to be extra sure
     * (time to sleep equals time it took for condition to turn true),
     * otherwise exact time to sleep before checking again.
     * @param pollPeriod How often (ms) to check for condition.
     * @param description Condition description.
     * @return Whatever condition returns.
     * @throws TimeoutException If condition did not happen.
     */
    static <T> T waitForCondition(
            @Nonnull Closure<T> condition,
            @Nonnull Duration timeout = Duration.ofSeconds(30),
            @Nullable Duration confidence = Duration.ZERO,
            @Nonnull Long pollPeriod = 500L,
            @Nullable String description = null)
            throws TimeoutException {
        Instant startTime = Instant.now()
        String conditionToUse = description ?: condition
        log.info "Waiting $timeout for condition: ${conditionToUse}"
        while (Instant.now().isBefore(startTime + timeout)) {
            List<T> result = safely(condition,description)
            if (result?.first()) {
                Duration elapsed = Duration.between(startTime, Instant.now())
                if (confidence == null) {
                    log.info "Condition ${conditionToUse} matched after $elapsed sec"
                    return result.first()
                }
                Duration confidenceTimeout = confidence == Duration.ZERO ?
                        elapsed :
                        confidence
                log.info "Condition ${conditionToUse} matched after $elapsed; " +
                        "will be checked again after $confidenceTimeout"
                Thread.sleep(confidenceTimeout.toMillis())
                result = safely(condition,description)
                if (result?.first()) {
                    log.info "Condition ${conditionToUse} again matched after $confidenceTimeout"
                    return result.first()
                }
                break
            }
            Thread.sleep(pollPeriod)
        }
        throw new TimeoutException("Failed to observe condition ${conditionToUse} within $timeout")
    }

    private static <T> List<T> safely(Closure<T> condition, String description) {
        String conditionToUse = description ?: condition
        try {
            [condition()]
        } catch (Exception e) {
            log.info("Condition $conditionToUse has failed: " + e.message)
            null
        }
    }

}
