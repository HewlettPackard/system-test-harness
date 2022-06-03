import groovy.json.JsonGenerator
import groovy.json.JsonOutput
import groovy.json.JsonSlurper
import groovy.transform.CompileStatic
import groovy.transform.ToString
import groovy.transform.stc.ClosureParams
import groovy.transform.stc.FirstParam
import groovy.util.logging.Log4j2
import org.apache.camel.*
import org.apache.camel.builder.EndpointProducerBuilder
import org.apache.camel.builder.RouteBuilder
import org.apache.camel.builder.endpoint.EndpointBuilderFactory
import org.apache.camel.component.mock.MockEndpoint
import org.apache.camel.converter.stream.InputStreamCache
import org.apache.camel.http.base.HttpOperationFailedException
import org.apache.camel.http.common.HttpMethods
import org.apache.camel.impl.DefaultCamelContext
import org.apache.camel.impl.engine.DefaultStreamCachingStrategy
import org.apache.camel.support.DefaultRegistry
import org.apache.commons.lang3.tuple.MutablePair
import org.apache.commons.lang3.tuple.Pair
import org.apache.http.HttpHeaders
import org.apache.http.NameValuePair
import org.apache.http.client.utils.URLEncodedUtils
import org.codehaus.groovy.runtime.NullObject

import javax.annotation.Nonnull
import javax.annotation.Nullable
import java.nio.charset.StandardCharsets
import java.time.Duration
import java.time.Instant
import java.time.format.DateTimeFormatter
import java.util.concurrent.TimeoutException
import java.util.function.Function
import java.util.stream.Collectors

/**
 * A simulator that sends alarms using integrated Camel context and route builder.
 * Starts/stops context automatically (this is not thread safe).
 */
@Log4j2('routeConfigLog')
// Yes, we want all-in-one simulator
@SuppressWarnings('ClassSize')
@CompileStatic
class Simulator {

    @ToString(includeNames = true, includePackage = false)
    static class Cfg {

        /**
         * The version of EMS to which adapter connects.
         */
        String emsVersion

        /**
         * Network port where adapter should listen for real time events.
         */
        @Nonnull
        String adapterRtListenPort

        /**
         * Network port where adapter will send resynchronization and other requests.
         */
        @Nonnull
        String emsActionListenPort

        /**
         * A network port where adapter will listen for action requests.
         */
        String adapterActionListenPort

        /**
         * UMB topic to send events to.
         */
        String topic

        /**
         * Kafka configuration to use when simulating AM.
         */
        String consumerConfig = 'consumer.properties'

        /**
         * Poll timeout for Kafka consumer when simulating AM.
         */
        Long pollTimeoutMs = 500

        /**
         * Specifies if routes related to simulating AM should be created and started.
         */
        Boolean simulateAm = false
    }

    @Nonnull
    Cfg cfg

    @Nonnull
    static Cfg loadCfg() {
        final int kvPartsCount = 2
        String simOptsVar = System.getenv('SIM_OPTS')
        assert simOptsVar: 'The simulator requires SIM_OPTS to be correctly setup with simulator configuration'
        Map<String, String> simOpts = simOptsVar.split(/;/)*.trim().grep().collectEntries {
            List<String> kv = it.split(/=/, kvPartsCount).toList()
            assert kv.size() == kvPartsCount: "Cannot parse '$it' key/value pair from SIM_OPTS: $simOptsVar"
            assert kv[0]: "Malformed simulator configuration in SIM_OPTS: $simOptsVar"
            kv
        }
        Cfg cfg = new Cfg()
        simOpts.each { option, value ->
            MetaProperty property = cfg.metaClass.properties.find { it.name == option }
            if (property) {
                property.setProperty(cfg, property.type == Boolean ?
                        Boolean.parseBoolean(value) :
                        value.asType(property.type))
            }
        }
        Cfg.declaredFields.each { field ->
            if (field.getAnnotation(Nonnull)) {
                assert cfg.metaClass.properties.find { it.name == field.name }.getProperty(cfg) != null:
                        "Simulator configuration property ${field.name} must be defined in SIM_OPTS: ${simOptsVar}"
            }
        }
        cfg
    }

    /**
     * Additional Camel exchange headers.
     */
    @Nullable
    Map<String, ?> messageHeaders = [:]

    /**
     * Camel context.
     */
    @Nullable
    DefaultCamelContext camel

    /**
     * {@link ProducerTemplate} that sends to start of integrated route by default.
     */
    @Nullable
    ProducerTemplate amActionsRequestSender

    /**
     * Template that simulates EMS sending events.
     */
    @Nullable
    ProducerTemplate emsEventsProducer

    /**
     * Simulates EMS receiving resynchronization requests.
     */
    @Nullable
    MockEndpoint emsResyncMock

    /**
     * Simulates EMS receiving custom directives requests.
     */
    @Nullable
    MockEndpoint emsCustomDirectiveMock

    /**
     * Simulates EMS receiving downward acknowledgment requests.
     */
    @Nullable
    MockEndpoint emsDownAckMock

    /**
     * A path to file to be created when Camel context has been started.
     */
    @Nullable
    String startedMarkerFilePath

    /**
     * Level at which to trace data exchanges.
     */
    @Nonnull
    String traceLevel = 'INFO'

    /**
     * Should we start Camel and simulate EMS?
     */
    boolean simulateEms = true

    /**
     * Custom simulator initialization.
     */
    void configure() {
        cfg = loadCfg()
        routeConfigLog.info("Simulator configuration: $cfg")
        assert !camel
        camel = new DefaultCamelContext()
        camel.streamCaching = true
        camel.streamCachingStrategy = new DefaultStreamCachingStrategy(spoolThreshold: -1)
        camel.globalOptions[Exchange.LOG_DEBUG_BODY_STREAMS] = 'true'
        camel.registry = new DefaultRegistry()
        if (simulateEms) {
            emsEventsProducer = camel.createProducerTemplate()
            emsEventsProducer.defaultEndpointUri = 'direct:emsEventsProducer'
        }
        if (cfg.simulateAm) {
            amActionsRequestSender = camel.createProducerTemplate()
            amActionsRequestSender.defaultEndpointUri = 'direct:amActionsRequestSender'
        }
        addShutdownHook {
            stop()
        }
        camel.addStartupListener(new ExtendedStartupListener() {
            @Override
            void onCamelContextFullyStarted(CamelContext context, boolean alreadyStarted) throws Exception {
                // Things like Jetty are super async and may not be fully ready yet
                Thread.sleep(200)
                if (startedMarkerFilePath) {
                    new File(startedMarkerFilePath).text = 'Started'
                }
            }

            @Override
            void onCamelContextStarted(CamelContext context, boolean alreadyStarted) throws Exception {
                // Here we are not yet fully started!
            }
        })
        if (perVersionInit) {
            assert cfg.emsVersion
            assert perVersionInit[cfg.emsVersion]
            perVersionInit[cfg.emsVersion].call()
        }
    }

    /**
     * Create log endpoint builder for tracing.
     *
     * This trace is controlled by {@link Simulator#traceLevel}.
     *
     * @param logger Logger to user.
     * @return Trace endpoint builder.
     */
    EndpointProducerBuilder trace(String logger) {
        EndpointBuilder.instance
                .log(logger)
                .level(traceLevel)
                .showBodyType(true)
                .showStreams(true)
                .showHeaders(true)
                .showExchangePattern(false)
                .skipBodyLineSeparator(true)
    }

    /**
     * Creates route that simulates EMS real time channel.
     * @param builder Builder to use to create route.
     */
    void configEmsRt(RouteBuilder builder) {
        builder.from(emsEventsProducer.defaultEndpoint.endpointUri)
                .routeId('emsRt')
                .to(trace('EMS_sent_event'))
                .setProperty(Exchange.CHARSET_NAME).constant('UTF-8')
                .doTry()
                .to(EndpointBuilder.instance.http("localhost:${cfg.adapterRtListenPort}"))
                .to(trace('EMS_received_reply'))
                .doCatch(HttpOperationFailedException)
                .process()
                .exchange { exchange ->
                    HttpOperationFailedException exception =
                            exchange.getProperty(Exchange.EXCEPTION_CAUGHT) as HttpOperationFailedException
                    throw new CamelExecutionException(
                            "Bad response code ${exception.statusCode} from ${exception.uri}:\n" +
                                    exception.responseBody, exchange)
                }
                .endDoTry()
    }

    /**
     * Creates route that simulates EMS resynchronization channel.
     * @param builder Builder to use to create route.
     */
    void configEmsResync(RouteBuilder builder) {
        emsResyncMock = camel.getEndpoint('mock:resync', MockEndpoint)
        emsResyncMock.returnReplyBody({ Exchange exchange, Class type ->
            throw new IOException('Not stubbed')
        } as Expression)
        builder.from(EndpointBuilder.instance.
                jetty("http://0.0.0.0:${cfg.emsActionListenPort}/tmb/10/alarms")
                .httpMethodRestrict('GET'))
                .routeId('emsResync')
                .to(trace('EMS_received_resync_request'))
                .to(emsResyncMock)
                .transform()
                .exchange {
                    Object body = it.message.body
                    switch (body) {
                        case NullObject:
                        case null:
                            null
                            break
                        case Map:
                            new JsonGenerator.Options().disableUnicodeEscaping().build().toJson(body)
                            break
                        case GString:
                            body.toString()
                            break
                        case String:
                            body
                            break
                        case InputStreamCache:
                            body
                            break
                        default:
                            throw new IllegalArgumentException("Unexpected reply type ${body.getClass()}: $body")
                    }
                }
                .setHeader(HttpHeaders.CONTENT_TYPE)
                .constant('application/json; charset=' + StandardCharsets.UTF_8.name())
                .setProperty(Exchange.CHARSET_NAME).constant(StandardCharsets.UTF_8.name())
                .to(trace('EMS_returned_resync_reply'))
    }

    /**
     * Creates route that simulates EMS custom directive channel.
     * @param builder Builder to use to create route.
     */
    void configEmsCustomDirective(RouteBuilder builder) {
        emsCustomDirectiveMock = camel.getEndpoint('mock:customDirective', MockEndpoint)
        emsCustomDirectiveMock.returnReplyBody({ Exchange exchange, Class type ->
            throw new IOException('Not stubbed')
        } as Expression)
        builder.from(EndpointBuilder.instance.
                jetty("http://0.0.0.0:${cfg.emsActionListenPort}/tmb/10/directive"))
                .routeId('emsCustomDirective')
                .to(trace('EMS_received_custom_command_request'))
                .to(emsCustomDirectiveMock)
                .transform()
                .exchange {
                    Object body = it.message.body
                    switch (body) {
                        case NullObject:
                        case null:
                            null
                            break
                        case Map:
                            new JsonGenerator.Options().disableUnicodeEscaping().build().toJson(body)
                            break
                        case GString:
                            body.toString()
                            break
                        case String:
                            body
                            break
                        case InputStreamCache:
                            body
                            break
                        default:
                            throw new IllegalArgumentException("Unexpected reply type ${body.getClass()}: $body")
                    }
                }
                .setHeader(HttpHeaders.CONTENT_TYPE)
                .constant('application/json; charset=' + StandardCharsets.UTF_8.name())
                .setProperty(Exchange.CHARSET_NAME).constant(StandardCharsets.UTF_8.name())
                .to(trace('EMS_returned_custom_command_reply'))
    }

    /**
     * Creates route that simulates EMS downward acknowledgment channel.
     * @param builder Builder to use to create route.
     */
    void configEmsDownAck(RouteBuilder builder) {
        emsDownAckMock = camel.getEndpoint('mock:downAck', MockEndpoint)
        emsDownAckMock.returnReplyBody({ Exchange exchange, Class type ->
            throw new IOException('Not stubbed')
        } as Expression)
        builder.from(EndpointBuilder.instance.
                jetty("http://0.0.0.0:${cfg.emsActionListenPort}/tmb/10/alarms/")
                .httpMethodRestrict('PATCH')
                .matchOnUriPrefix(true))
                .routeId('emsDownAck')
                .to(trace('EMS_received_downack_request'))
                .to(emsDownAckMock)
                .transform()
                .exchange {
                    Object body = it.message.body
                    switch (body) {
                        case NullObject:
                        case null:
                            null
                            break
                        case Map:
                            new JsonGenerator.Options().disableUnicodeEscaping().build().toJson(body)
                            break
                        case GString:
                            body.toString()
                            break
                        case String:
                            body
                            break
                        case InputStreamCache:
                            body
                            break
                        default:
                            throw new IllegalArgumentException("Unexpected reply type ${body.getClass()}: $body")
                    }
                }
                .setHeader(HttpHeaders.CONTENT_TYPE)
                .constant('application/json; charset=' + StandardCharsets.UTF_8.name())
                .setProperty(Exchange.CHARSET_NAME).constant(StandardCharsets.UTF_8.name())
                .to(trace('EMS_returned_downack_reply'))
    }

    /**
     * Gets parameters of HTTP query.
     * @param exchange Exchange where to extract query parameters from.
     * @return Map of HTTP query parameters as recorded by HTTP component using
     * {@link Exchange#HTTP_QUERY} header or an empty map if none.
     */
    Map<String, String> parseQueryParams(Exchange exchange) {
        String query = exchange.message.getHeader(Exchange.HTTP_QUERY, String)
        if (!query) {
            return [:]
        }
        List<NameValuePair> params = URLEncodedUtils.parse(query, StandardCharsets.UTF_8)
        Map<String, String> flattenedParams = params
                .stream()
                .collect(Collectors.toMap(
                        { NameValuePair pair -> pair.name } as Function<NameValuePair, String>,
                        { NameValuePair pair -> pair.value } as Function<NameValuePair, String>))
        flattenedParams
    }

    /**
     * Gets path of HTTP request.
     * @param exchange Exchange which PATH to get.
     * @return Path of request.
     */
    String parsePath(Exchange exchange) {
        exchange.message.headers[Exchange.HTTP_URI].asType(String).tokenize('?').first()
    }

    /**
     * Gets method of HTTP request.
     * @param exchange Exchange which method to get.
     * @return Method of request.
     */
    String parseMethod(Exchange exchange) {
        exchange.message.headers['CamelHttpMethod'].asType(String)
    }

    /**
     * Creates route that simulates AM actions channel.
     * @param builder Builder to use to create route.
     */
    void configAmActions(RouteBuilder builder) {
        assert cfg.adapterActionListenPort
        builder.from(amActionsRequestSender.defaultEndpoint.endpointUri)
                .routeId('amActions')
                .to(trace('AM_sent_request'))
                .to(EndpointBuilder.instance.http("localhost:${cfg.adapterActionListenPort}/")
                        .throwExceptionOnFailure(false)
                )
                .to(trace('AM_received_reply'))
    }

    /**
     * Creates route that simulates AM events channel.
     * @param builder Builder to use to create route.
     */
    void configAmRt(RouteBuilder builder) {
        String amRtComponent = 'amKafka'
        camel.registry.bind('amKafkaConsumerConfig', Properties, loadPropertiesFromResource(cfg.consumerConfig))
        camel.registry.bind('amKafkaHeadersToPropagate', List<String>,
                ['key',
                 'offset',
                 'partition',
                 'timestamp',
                 'timestampType',
                 'topic',])
        builder.from("${amRtComponent}://dynamicConsumer" +
                "?topics=${cfg.topic}" +
                "&pollTimeoutMs=${cfg.pollTimeoutMs}" +
                '&config=#amKafkaConsumerConfig' +
                '&metricsNamePrefix=rt.am.')
                .routeId('amRt')
                .to(trace('AM_received_event'))
                .process()
                .exchange { exchange ->
                    Map<String, ?> event = exchange.in.getMandatoryBody(Map)
                    Map<String, ?> messageProperties = exchange.in.headers
                    amRtEventsReceived.add(new Tuple2<>(event, messageProperties))
                    onAmRtEvent(event, messageProperties)
                }
    }

    /**
     * Loads properties from classpath resources.
     */
    private @Nonnull
    Properties loadPropertiesFromResource(@Nonnull String resource) {
        InputStream configFileStream = getClass().classLoader.getResourceAsStream(resource)
        if (!configFileStream) {
            throw new IOException("Cannot find configuration file: ${resource}")
        }
        Properties properties = new Properties()
        configFileStream.withReader { Reader reader ->
            properties.load(reader)
        }
        properties
    }

    /**
     * Starts Camel.
     *
     * Automatically registers shutdown hook to stop Camel.
     *
     * @throws AssertionError If already started.
     */
    void start() {
        configure()
        assert camel
        RouteBuilder.addRoutes(camel, {
            if (simulateEms) {
                routeConfigLog.info('EMS simulation is enabled')
                configEmsRt(it)
                configEmsResync(it)
                configEmsCustomDirective(it)
                configEmsDownAck(it)
            } else {
                routeConfigLog.info('Not simulating EMS because it is disabled')
            }
            if (cfg.simulateAm) {
                routeConfigLog.info('AM simulation is enabled')
                configAmRt(it)
                configAmActions(it)
            } else {
                routeConfigLog.info('Not simulating AM because it is disabled')
            }
        })
        camel.start()
        //workaround for problem:
        // if to send event too early, the kafka consumer still not finish the offset sync with broker
        //it will cause the event can't be consumed as expected
        if (cfg.simulateAm) {
            try {
                //sleep a while to wait kafka consumer finish its initialize
                //(mainly to get the offset before message produced)
                sleep 1500
            } catch (InterruptedException ie) {
                routeConfigLog.info('Interrupted to wait for kafka initialization')
            }
        }
    }

    /**
     * Stops Camel.
     *
     * Doesn't do anything if Camel wasn't previously started.
     */
    void stop() {
        if (camel) {
            Instant whenStop = Instant.now().plusSeconds(5)
            while (camel.inflightRepository.size() && Instant.now().isBefore(whenStop)) {
                Thread.sleep(100)
            }
            camel.shutdown()
        }
    }

    /**
     * Sends specified events to adapter.
     *
     * Automatically starts Camel if needed.
     *
     * @param events Payload to send.
     * @return Pair where {@link org.apache.commons.lang3.tuple.Pair#getLeft} indicates
     * if adapter has indicated success HTTP response code or error one and
     * {@link org.apache.commons.lang3.tuple.Pair#getRight} is unmarshalled JSON reply from adapter.
     * Error indication as per RFC 2616  section '10 Status Code Definitions' and will be indicated as true in
     * {@link org.apache.commons.lang3.tuple.Pair#getLeft}.
     */
    Pair<Boolean, Map<String, Object>> emsSendEvents(String events) {
        if (!camel) {
            start()
        }
        assert camel
        assert emsEventsProducer

        Exchange callResult = emsEventsProducer.request(
                emsEventsProducer.defaultEndpoint, {
            it.message.body = events
        })
        MutablePair<Boolean, Map<String, Object>> result = new MutablePair<>(true, null)
        String body = callResult.context.typeConverter.tryConvertTo(String, callResult, callResult.message.body)
        if (!(callResult.message.headers[Exchange.HTTP_RESPONSE_CODE].asType(Integer) in (200..299))) {
            result.left = false
        }
        if (callResult.exception != null) {
            throw callResult.exception
        }
        if (body) {
            result.right = Map<String, Object>.cast(new JsonSlurper().parseText(body))
        }
        result
    }

    /**
     * Sends specified events to adapter.
     *
     * Automatically starts Camel if needed.
     *
     * @param events List of maps each representing an alarm that will be converted to JSON.
     * @return Pair where {@link org.apache.commons.lang3.tuple.Pair#getLeft} indicates
     * if adapter has indicated success HTTP response code or error one and
     * {@link org.apache.commons.lang3.tuple.Pair#getRight} is unmarshalled JSON reply from adapter.
     * Error indication as per RFC 2616  section '10 Status Code Definitions' and will be indicated as true in
     * {@link org.apache.commons.lang3.tuple.Pair#getLeft}.*
     */
    Pair<Boolean, Map<String, Object>> emsSendEvents(List<Map<String, Object>> events) {
        emsSendEvents(JsonOutput.toJson(events))
    }

    /**
     * Sends resynchronization request to adapter.
     * @param continuePreviousRequest The value of continuePreviousRequest parameter or null if should be absent.
     * @param iterator The value of iterator parameter or null if should be absent.
     * @target Target on which AM requests to perform scoped resynchronization or null if full.
     * @return Pair where {@link org.apache.commons.lang3.tuple.Pair#getLeft} indicates
     * if adapter has indicated success HTTP response code or error one and
     * {@link org.apache.commons.lang3.tuple.Pair#getRight} is unmarshalled JSON reply from adapter.
     * Error indication as per unified format is not considered to be an error and will be indicated as true in
     * {@link org.apache.commons.lang3.tuple.Pair#getLeft}.
     */
    Pair<Boolean, Map<String, ?>> amRequestResync(Boolean continuePreviousRequest,
                                                  String iterator,
                                                  String target = null) {
        if (!camel) {
            start()
        }
        assert camel
        assert amActionsRequestSender
        Exchange callResult = amActionsRequestSender.request(amActionsRequestSender.defaultEndpoint, {
            it.message.body = null
            it.message.headers[Exchange.HTTP_METHOD] = HttpMethods.GET.name()
            it.message.headers[Exchange.HTTP_PATH] = 'tmb/10/alarms'
            it.message.headers[HttpHeaders.ACCEPT] = 'application/json'
            it.message.headers[HttpHeaders.ACCEPT_CHARSET] = StandardCharsets.UTF_8.name()
            Map<String, String> query = [:]
            if (continuePreviousRequest != null) {
                query['continuePreviousRequest'] = continuePreviousRequest.toString()
            }
            if (iterator != null) {
                query['iterator'] = iterator
            }
            if (target != null) {
                query['filter'] = JsonOutput.toJson([
                        [
                                field    : 'directiveTarget',
                                operation: '=',
                                'value'  : target,
                        ]
                ])
            }
            if (!query.isEmpty()) {
                it.message.headers[Exchange.HTTP_QUERY] = query.collect { k, v -> "$k=$v" }.join('&&')
            }
            it.message.headers << messageHeaders
        })
        MutablePair<Boolean, Map<String, ?>> result = new MutablePair<>(true, [:])
        String body = callResult.context.typeConverter.tryConvertTo(String, callResult, callResult.message.body)
        if (!(callResult.message.headers[Exchange.HTTP_RESPONSE_CODE].asType(Integer) in (200..299))) {
            result.left = false
        }
        if (callResult.exception != null) {
            throw callResult.exception
        }
        if (body) {
            result.right = Map.cast(new JsonSlurper().parseText(body))
        }
        result
    }

    /**
     * Sends custom directive request to adapter.
     * @param directiveName Name of the directive to call.
     * @param directiveTarget Target on which directive is to be called.
     * @param parameters Additional parameters of the directive or an empty map if none.
     * @return Pair where {@link org.apache.commons.lang3.tuple.Pair#getLeft} indicates
     * if adapter has indicated success HTTP response code or error one and
     * {@link org.apache.commons.lang3.tuple.Pair#getRight} is unmarshalled JSON reply from adapter.
     * Error indication as per unified format is not considered to be an error and will be indicated as true in
     * {@link org.apache.commons.lang3.tuple.Pair#getLeft}.
     */
    Pair<Boolean, Map<String, ?>> amRequestCustomDirective(
            String directiveName,
            String directiveTarget,
            Map<String, ?> parameters = [:]) {
        if (!camel) {
            start()
        }
        assert camel
        assert amActionsRequestSender
        Exchange callResult = amActionsRequestSender.request(amActionsRequestSender.defaultEndpoint, {
            it.message.body = JsonOutput.toJson(
                    [
                            directiveName  : directiveName as Object,
                            directiveTarget: directiveTarget as Object,
                    ] + parameters)
            it.message.headers[Exchange.HTTP_METHOD] = HttpMethods.POST.name()
            it.message.headers[HttpHeaders.CONTENT_TYPE] =
                    'application/merge-patch+json; charset=' + StandardCharsets.UTF_8.name()
            it.message.headers[Exchange.HTTP_PATH] = 'tmb/10/directive'
            it.message.headers[HttpHeaders.ACCEPT] = 'application/json'
            it.message.headers[HttpHeaders.ACCEPT_CHARSET] = StandardCharsets.UTF_8.name()
            it.message.headers << messageHeaders
        })
        MutablePair<Boolean, Map<String, ?>> result = new MutablePair<>(true, [:])
        String body = callResult.context.typeConverter.tryConvertTo(String, callResult, callResult.message.body)
        if (!(callResult.message.headers[Exchange.HTTP_RESPONSE_CODE].asType(Integer) in (200..299))) {
            result.left = false
        }
        if (callResult.exception != null) {
            throw callResult.exception
        }
        if (body) {
            result.right = Map.cast(new JsonSlurper().parseText(body))
        }
        result
    }

    /**
     * Sends downward acknowledgment request to adapter.
     * @param alarmId alarmId of alarm to be acknowledged.
     * @param ackstate true if alarm is to be acknowledged, false if alarm is to be unacknowledged.
     * @param ackUserId Identifier of user requesting alarm acknowledgment or null if parameter is not to be sent.
     * @param ackSystemId Identifier of system requesting alarm acknowledgment or null if parameter is not to be sent.
     * @return Pair where {@link org.apache.commons.lang3.tuple.Pair#getLeft} indicates
     * if adapter has indicated success HTTP response code or error one and
     * {@link org.apache.commons.lang3.tuple.Pair#getRight} is unmarshalled JSON reply from adapter.
     * Error indication as per unified format is not considered to be an error and will be indicated as true in
     * {@link org.apache.commons.lang3.tuple.Pair#getLeft}.
     * If adapter returned no payload in reply then {@link org.apache.commons.lang3.tuple.Pair#getRight}
     * will be null.
     */
    Pair<Boolean, Map<String, ?>> amRequestAck(
            String alarmId,
            boolean ackstate,
            String ackUserId,
            String ackSystemId) {
        if (!camel) {
            start()
        }
        assert camel
        assert amActionsRequestSender
        Exchange callResult = amActionsRequestSender.request(amActionsRequestSender.defaultEndpoint, {
            Map<String, String> payload = ['ackstate': (ackstate ? 'acknowledged' : 'unacknowledged')]
            if (ackUserId != null) {
                payload['ackUserId'] = ackUserId
            }
            if (ackSystemId != null) {
                payload['ackSystemId'] = ackSystemId
            }
            it.message.body = JsonOutput.toJson(payload)
            it.message.headers[Exchange.HTTP_METHOD] = HttpMethods.PATCH.name()
            it.message.headers[HttpHeaders.CONTENT_TYPE] =
                    'application/merge-patch+json; charset=' + StandardCharsets.UTF_8.name()
            it.message.headers[Exchange.HTTP_PATH] = 'tmb/10/alarms/' + alarmId
            it.message.headers[HttpHeaders.ACCEPT] = 'application/json'
            it.message.headers[HttpHeaders.ACCEPT_CHARSET] = StandardCharsets.UTF_8.name()
            it.message.headers << messageHeaders
        })
        MutablePair<Boolean, Map<String, ?>> result = new MutablePair<>(true, null)
        String body = callResult.context.typeConverter.tryConvertTo(String, callResult, callResult.message.body)
        if (!(callResult.message.headers[Exchange.HTTP_RESPONSE_CODE].asType(Integer) in (200..299))) {
            result.left = false
        }
        if (callResult.exception != null) {
            throw callResult.exception
        }
        if (body) {
            result.right = Map.cast(new JsonSlurper().parseText(body))
        }
        result
    }

    /**
     * Run closure within Camel context.
     *
     * Initializes camel before running the closure and shuts down camel after running the closure.
     *
     * @param closure Code to run with Camel active.
     */
    Object call(
            @DelegatesTo(value = Simulator, strategy = Closure.DELEGATE_FIRST)
            @ClosureParams(FirstParam)
                    Closure<?> closure) {
        Closure<?> clonedClosure = closure.clone() as Closure
        clonedClosure.resolveStrategy = Closure.DELEGATE_FIRST
        clonedClosure.delegate = this
        start()
        try {
            Object result = clonedClosure.call(this)
            if (startedMarkerFilePath) {
                new File(startedMarkerFilePath).text = 'Successfully finished'
            }
            return result
        } finally {
            stop()
        }
    }

    /**
     * EMS version specific initialization of client library.
     */
    Map<String, Closure<Void>> perVersionInit = [
            :
    ]

    /**
     * What to do when AM real time channel receives an event.
     *
     * By default, does nothing.
     *
     * Closure should take  Map<String, ?> event and Map<String,?> with headers (topic, partition, etc).
     */
    Closure<?> onAmRtEvent = { Map<String, ?> event, Map<String, ?> messageProperties ->
    }

    /**
     * Events received by AM real time channel simulator.
     *
     * {@link Tuple2#v1} - event.
     * {@link Tuple2#v2} - properties of message (topic, partition, etc).
     */
    @Nonnull
    final List<Tuple2<Map<String, ?>, Map<String, ?>>> amRtEventsReceived =
            Collections.synchronizedList(new ArrayList<>())

    /**
     * Waits until AM receives specified number of events.
     * @param count Number of events to wait for.
     * @throws java.util.concurrent.TimeoutException If AM did not receive specified number of events.
     */
    void waitAmEventsReceived(int count, Duration timeout = Duration.ofSeconds(10)) {
        LibWait.waitForCondition({ amRtEventsReceived.size() >= count },
                timeout,
                Duration.ZERO,
                500L,
                "AM received $count events")
        if (amRtEventsReceived.size() > count) {
            throw new TimeoutException('Too much events were received: ' +
                    "expected $count but got ${amRtEventsReceived.size()}. Events are:\n" +
                    amRtEventsReceived*.v1*.toString().join('\n'))
        }
    }

    /**
     * Parses date/time in the bus (ISO extended) format back to Java format.
     * @param date Date/time to parse. Expected to be String.
     * @return Parsed date/time.
     */
    Instant parseBusDate(Object date) {
        Instant.from(DateTimeFormatter.ISO_DATE_TIME.parse(String.cast(date)))
    }

    /**
     * Annotate an action taken by test.
     * @param message Action description.
     */
    void annotate_action(String message) {
        routeConfigLog.info("TEST ACTION: $message")
    }

    /**
     * Annotate a check performed by test.
     * @param message Check description.
     */
    void annotate_check(String message) {
        routeConfigLog.info("TEST CHECK: $message")
    }

    @Singleton
    @CompileStatic
    static class EndpointBuilder implements EndpointBuilderFactory {
    }

}
