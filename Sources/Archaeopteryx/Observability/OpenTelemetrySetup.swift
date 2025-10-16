import Foundation
import Logging
import Metrics
import OTel
import OTLPGRPC
import ServiceLifecycle
import Tracing

/// OpenTelemetry configuration and setup
///
/// This module configures OpenTelemetry for Archaeopteryx, providing:
/// - **Logging**: Structured logs exported via OTLP
/// - **Tracing**: Distributed tracing with W3C TraceContext propagation
/// - **Metrics**: Application and HTTP metrics exported periodically
///
/// All telemetry data is exported to an OTLP/gRPC collector (e.g., Grafana Agent, OpenTelemetry Collector).
public struct OpenTelemetrySetup: Sendable {
    /// Service name for telemetry
    public let serviceName: String

    /// Service version
    public let serviceVersion: String

    /// Environment (development, staging, production)
    public let environment: String

    /// OTLP collector endpoint (e.g., "http://localhost:4317")
    public let otlpEndpoint: String

    /// Whether to enable tracing
    public let tracingEnabled: Bool

    /// Whether to enable metrics
    public let metricsEnabled: Bool

    public init(
        serviceName: String = "archaeopteryx",
        serviceVersion: String = "1.0.0",
        environment: String = "development",
        otlpEndpoint: String = "http://localhost:4317",
        tracingEnabled: Bool = true,
        metricsEnabled: Bool = true
    ) {
        self.serviceName = serviceName
        self.serviceVersion = serviceVersion
        self.environment = environment
        self.otlpEndpoint = otlpEndpoint
        self.tracingEnabled = tracingEnabled
        self.metricsEnabled = metricsEnabled
    }

    /// Bootstrap OpenTelemetry system
    ///
    /// This sets up:
    /// - Logging backend with OTel metadata provider (includes span IDs in logs)
    /// - Metrics backend with OTLP/gRPC exporter
    /// - Tracing backend with OTLP/gRPC exporter and W3C propagation
    ///
    /// Returns a tuple of services that must be added to the application lifecycle.
    public func bootstrap(logLevel: Logger.Level = .info) async throws -> (
        metricsReader: (any Service)?,
        tracer: (any Service)?
    ) {
        // Bootstrap logging with OTel metadata provider to include span IDs
        LoggingSystem.bootstrap { label in
            var handler = StreamLogHandler.standardOutput(label: label, metadataProvider: .otel)
            handler.logLevel = logLevel

            // Add default metadata for all logs
            handler.metadata = [
                "service.name": "\(serviceName)",
                "service.version": "\(serviceVersion)",
                "environment": "\(environment)",
            ]

            return handler
        }

        // Configure OTel resource detection to automatically apply helpful attributes
        let otelEnvironment = OTelEnvironment.detected()
        let resourceDetection = OTelResourceDetection(detectors: [
            OTelProcessResourceDetector(),
            OTelEnvironmentResourceDetector(environment: otelEnvironment),
            .manual(OTelResource(attributes: [
                "service.name": .string(serviceName),
                "service.version": .string(serviceVersion),
                "deployment.environment": .string(environment),
            ])),
        ])
        let resource = await resourceDetection.resource(environment: otelEnvironment, logLevel: logLevel)

        var metricsReader: (any Service)? = nil
        var tracer: (any Service)? = nil

        // Bootstrap metrics if enabled
        if metricsEnabled {
            let registry = OTelMetricRegistry()
            let metricsExporter = try OTLPGRPCMetricExporter(configuration: .init(environment: otelEnvironment))
            metricsReader = OTelPeriodicExportingMetricsReader(
                resource: resource,
                producer: registry,
                exporter: metricsExporter,
                configuration: .init(environment: otelEnvironment)
            )
            MetricsSystem.bootstrap(OTLPMetricsFactory(registry: registry))
        }

        // Bootstrap tracing if enabled
        if tracingEnabled {
            let exporter = try OTLPGRPCSpanExporter(configuration: .init(environment: otelEnvironment))
            let processor = OTelBatchSpanProcessor(
                exporter: exporter,
                configuration: .init(environment: otelEnvironment)
            )
            let otelTracer = OTelTracer(
                idGenerator: OTelRandomIDGenerator(),
                sampler: OTelConstantSampler(isOn: true),
                propagator: OTelW3CPropagator(),
                processor: processor,
                environment: otelEnvironment,
                resource: resource
            )
            InstrumentationSystem.bootstrap(otelTracer)
            tracer = otelTracer
        }

        return (metricsReader, tracer)
    }
}
