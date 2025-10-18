# OpenTelemetry Observability

Monitor Archaeopteryx with logs, traces, and metrics via OpenTelemetry.

## Overview

Archaeopteryx includes full OpenTelemetry (OTel) support for observability:

- **Logs** - Structured logging with span correlation
- **Traces** - Distributed tracing for request flows
- **Metrics** - HTTP request counters, duration histograms, error rates

All telemetry exports via OTLP/gRPC to your backend (Grafana, Jaeger, Prometheus, etc.).

## Quick Start

Enable OpenTelemetry by setting an environment variable:

```bash
export OTLP_ENDPOINT="http://localhost:4317"
swift run Archaeopteryx
```

## Configuration

### Environment Variables

```bash
# Required: OTLP collector endpoint
export OTLP_ENDPOINT="http://localhost:4317"

# Optional: Enable/disable signals
export TRACING_ENABLED="true"   # default: true
export METRICS_ENABLED="true"   # default: true

# Optional: Service identification
export ENVIRONMENT="production"  # default: development
export LOG_LEVEL="info"          # default: info
```

## Features

### Traces

Distributed tracing with automatic span creation:

- **Attributes**: HTTP method, path, status, duration, user agent
- **Correlation**: W3C TraceContext propagation
- **Error tracking**: Failed requests marked as errors
- **Timing**: Full request breakdown

### Logs

Structured logging with trace correlation:

- **Fields**: service name, version, environment, HTTP details
- **Correlation**: Automatic span ID injection
- **Levels**: trace, debug, info, warning, error
- **Export**: OTLP to Loki or other backends

### Metrics

HTTP metrics exported periodically:

- `http_server_requests_total` - Request counter by method, route, status
- `http_server_request_duration_seconds` - Duration histogram
- `http_server_active_requests` - Active request gauge
- `http_server_errors_total` - Error counter

## Grafana Cloud Setup

1. **Sign up** at [grafana.com](https://grafana.com/)

2. **Get OTLP endpoint**:
   - Navigate to Connections → Add connection
   - Select "OpenTelemetry (OTLP)"
   - Copy endpoint URL and token

3. **Configure Archaeopteryx**:
   ```bash
   export OTLP_ENDPOINT="https://otlp-gateway-prod-us-central-0.grafana.net/otlp"
   export OTEL_EXPORTER_OTLP_HEADERS="Authorization=Basic <your-token>"
   swift run Archaeopteryx
   ```

## Local Grafana Stack

Run Grafana + Tempo + Loki + Prometheus locally:

### Docker Compose

```yaml
services:
  otel-collector:
    image: otel/opentelemetry-collector-contrib:latest
    ports:
      - "4317:4317"  # OTLP gRPC
    volumes:
      - ./otel-collector-config.yaml:/etc/otel-collector-config.yaml

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    environment:
      - GF_AUTH_ANONYMOUS_ENABLED=true

  tempo:
    image: grafana/tempo:latest
    ports:
      - "3200:3200"

  loki:
    image: grafana/loki:latest
    ports:
      - "3100:3100"

  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
```

### Start Stack

```bash
docker-compose up -d
export OTLP_ENDPOINT="http://localhost:4317"
swift run Archaeopteryx
```

### Access Grafana

Open http://localhost:3000

**Configure data sources**:
- Tempo: `http://tempo:3200`
- Loki: `http://loki:3100`
- Prometheus: `http://prometheus:9090`

## Viewing Telemetry

### Traces

Navigate to Explore → Tempo:

- Search by service: `service.name="archaeopteryx"`
- Filter by duration: `duration > 500ms`
- Filter by errors: `status=error`
- Click traces to see request breakdown

### Logs

Navigate to Explore → Loki:

```
{service_name="archaeopteryx"}
{service_name="archaeopteryx"} |= "error"
{service_name="archaeopteryx"} | json | http_duration_ms > 500
```

### Metrics

Navigate to Explore → Prometheus:

```promql
# Request rate
rate(http_server_requests_total[5m])

# P95 latency
histogram_quantile(0.95, rate(http_server_request_duration_seconds_bucket[5m]))

# Error rate
rate(http_server_errors_total[5m]) / rate(http_server_requests_total[5m])
```

## Middleware

Archaeopteryx includes three observability middlewares:

### TracingMiddleware

Creates spans for every HTTP request:

```swift
router.middlewares.add(TracingMiddleware(logger: logger))
```

Captures: method, path, status, duration, user agent

### MetricsMiddleware

Collects HTTP metrics:

```swift
router.middlewares.add(MetricsMiddleware(logger: logger))
```

Exports: request counters, duration histograms, active requests

### LoggingMiddleware

Structured logging with trace correlation:

```swift
router.middlewares.add(LoggingMiddleware(logger: logger))
```

Includes: span ID, trace ID, service metadata

## Production Considerations

### Performance

- OTel adds ~1-5ms latency per request
- Use async exporters (default) to avoid blocking
- Consider sampling in high-traffic environments:

```swift
sampler: OTelConstantSampler(isOn: true, probability: 0.1)  // 10%
```

### Security

- Use TLS for OTLP endpoints
- Secure Grafana with authentication
- Use API keys for Grafana Cloud
- Redact sensitive data from logs

### Resource Limits

Tune batch sizes if needed:

```swift
maxQueueSize: 2048
maxExportBatchSize: 512
scheduleDelay: .seconds(5)
```

## Troubleshooting

### No Data in Grafana

1. Check OTLP_ENDPOINT is set:
   ```bash
   echo $OTLP_ENDPOINT
   ```

2. Verify collector is running:
   ```bash
   curl http://localhost:8888/metrics
   ```

3. Check Archaeopteryx logs:
   ```bash
   swift run Archaeopteryx 2>&1 | grep otel_enabled
   ```

4. Enable debug logging in collector

### No Traces

- Verify Tempo is receiving: `curl http://localhost:3200/api/search`
- Check collector logs: `docker-compose logs otel-collector`

### No Metrics

- Verify Prometheus targets: `curl http://localhost:9090/api/v1/targets`
- Check metric names: `curl http://localhost:8889/metrics | grep http_server`

## Example Queries

### Loki (Logs)

```logql
{service_name="archaeopteryx"}
{service_name="archaeopteryx"} |= "level=error"
{service_name="archaeopteryx"} | json | trace_id="abc123"
```

### Tempo (Traces)

```
service.name="archaeopteryx"
duration > 500ms
status=error
http.target="/api/v1/accounts/verify_credentials"
```

### Prometheus (Metrics)

```promql
# Requests per second
rate(http_server_requests_total[5m])

# By status code
sum by (http_status_code) (rate(http_server_requests_total[5m]))

# Active requests
http_server_active_requests
```

## Next Steps

1. Set up Grafana alerts for error rates, latency
2. Create dashboards for monitoring
3. Integrate with incident management (PagerDuty, Slack)
4. Analyze performance bottlenecks with traces
5. Correlate logs with traces for debugging

## See Also

- <doc:Getting-Started> - Run Archaeopteryx locally
- <doc:Fly-Deployment> - Deploy with observability
- [OpenTelemetry Docs](https://opentelemetry.io/docs/)
- Complete guide: `OPENTELEMETRY.md` in repository
