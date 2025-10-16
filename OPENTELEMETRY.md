# OpenTelemetry Integration Guide

Archaeopteryx includes full OpenTelemetry (OTel) support for observability, providing **logs**, **traces**, and **metrics** exported via OTLP/gRPC to your telemetry backend (Grafana, Jaeger, Prometheus, etc.).

## Features

### 📊 **Logs**
- Structured logging with span correlation
- All logs include service name, version, and environment
- Automatic span ID injection for distributed tracing correlation
- Exported to OTLP collector

### 🔍 **Traces**
- Distributed tracing with W3C TraceContext propagation
- Automatic HTTP span creation for all requests
- HTTP semantic conventions (method, status, duration, etc.)
- Parent-child span relationships for request flows
- Error tracking within spans

### 📈 **Metrics**
- HTTP request counters (by method, route, status)
- Request duration histograms
- Active request gauges
- Error counters
- Exported periodically to OTLP collector

---

## Configuration

### Environment Variables

Enable OpenTelemetry by setting the `OTLP_ENDPOINT` environment variable:

```bash
# Required: OTLP collector endpoint
export OTLP_ENDPOINT="http://localhost:4317"

# Optional: Enable/disable specific signals
export TRACING_ENABLED="true"  # default: true
export METRICS_ENABLED="true"  # default: true

# Optional: Service identification
export ENVIRONMENT="production"  # default: development
export LOG_LEVEL="info"          # default: info
```

### Configuration File

Alternatively, configure via code:

```swift
let config = ArchaeopteryxConfiguration(
    observability: ObservabilityConfiguration(
        otlpEndpoint: "http://localhost:4317",
        tracingEnabled: true,
        metricsEnabled: true
    ),
    environment: "production"
)
```

---

## Grafana Setup

### Option 1: Grafana Cloud (Easiest)

1. **Create a Grafana Cloud account** at https://grafana.com/
2. **Get your OTLP endpoint**:
   - Navigate to "Connections" → "Add new connection"
   - Select "OpenTelemetry (OTLP)"
   - Copy the endpoint URL and access token

3. **Configure Archaeopteryx**:
   ```bash
   export OTLP_ENDPOINT="https://otlp-gateway-prod-us-central-0.grafana.net/otlp"
   export OTEL_EXPORTER_OTLP_HEADERS="Authorization=Basic <base64_token>"
   ```

### Option 2: Local Grafana Stack (Docker Compose)

Create a `docker-compose.yml` for local development:

```yaml
version: '3.8'

services:
  # Grafana for visualization
  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    environment:
      - GF_AUTH_ANONYMOUS_ENABLED=true
      - GF_AUTH_ANONYMOUS_ORG_ROLE=Admin
    volumes:
      - grafana-data:/var/lib/grafana

  # OpenTelemetry Collector
  otel-collector:
    image: otel/opentelemetry-collector-contrib:latest
    command: ["--config=/etc/otel-collector-config.yaml"]
    ports:
      - "4317:4317"  # OTLP gRPC receiver
      - "4318:4318"  # OTLP HTTP receiver
      - "8888:8888"  # Prometheus metrics
      - "8889:8889"  # Prometheus exporter
    volumes:
      - ./otel-collector-config.yaml:/etc/otel-collector-config.yaml

  # Tempo for traces
  tempo:
    image: grafana/tempo:latest
    command: ["-config.file=/etc/tempo.yaml"]
    ports:
      - "3200:3200"  # Tempo
      - "4317"       # OTLP gRPC
    volumes:
      - ./tempo.yaml:/etc/tempo.yaml
      - tempo-data:/tmp/tempo

  # Loki for logs
  loki:
    image: grafana/loki:latest
    ports:
      - "3100:3100"
    command: -config.file=/etc/loki/local-config.yaml
    volumes:
      - loki-data:/loki

  # Prometheus for metrics
  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus-data:/prometheus

volumes:
  grafana-data:
  tempo-data:
  loki-data:
  prometheus-data:
```

**OpenTelemetry Collector Config** (`otel-collector-config.yaml`):

```yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

processors:
  batch:
    timeout: 10s
    send_batch_size: 1024

exporters:
  # Export traces to Tempo
  otlp/tempo:
    endpoint: tempo:4317
    tls:
      insecure: true

  # Export metrics to Prometheus
  prometheus:
    endpoint: "0.0.0.0:8889"

  # Export logs to Loki
  loki:
    endpoint: http://loki:3100/loki/api/v1/push

  # Debug exporter (logs to console)
  logging:
    loglevel: debug

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch]
      exporters: [otlp/tempo, logging]

    metrics:
      receivers: [otlp]
      processors: [batch]
      exporters: [prometheus, logging]

    logs:
      receivers: [otlp]
      processors: [batch]
      exporters: [loki, logging]
```

**Tempo Config** (`tempo.yaml`):

```yaml
server:
  http_listen_port: 3200

distributor:
  receivers:
    otlp:
      protocols:
        grpc:
          endpoint: 0.0.0.0:4317

storage:
  trace:
    backend: local
    local:
      path: /tmp/tempo/blocks
```

**Prometheus Config** (`prometheus.yml`):

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'otel-collector'
    static_configs:
      - targets: ['otel-collector:8889']

  - job_name: 'archaeopteryx'
    static_configs:
      - targets: ['host.docker.internal:8080']
```

---

## Running with OpenTelemetry

### 1. Start the Observability Stack

```bash
# Start Grafana + OTel Collector + Tempo + Loki + Prometheus
docker-compose up -d

# Verify services are running
docker-compose ps
```

### 2. Start Archaeopteryx

```bash
# With OTel enabled
export OTLP_ENDPOINT="http://localhost:4317"
export ENVIRONMENT="development"
export LOG_LEVEL="info"

swift run Archaeopteryx
```

### 3. Access Grafana

Open http://localhost:3000 in your browser.

#### **Configure Data Sources**:

1. **Tempo (Traces)**:
   - Go to Configuration → Data Sources
   - Add "Tempo"
   - URL: `http://tempo:3200`

2. **Loki (Logs)**:
   - Add "Loki"
   - URL: `http://loki:3100`

3. **Prometheus (Metrics)**:
   - Add "Prometheus"
   - URL: `http://prometheus:9090`

#### **View Telemetry**:

- **Traces**: Go to "Explore" → Select "Tempo" → View distributed traces
- **Logs**: Go to "Explore" → Select "Loki" → Query logs with `{service_name="archaeopteryx"}`
- **Metrics**: Go to "Explore" → Select "Prometheus" → Query metrics like `http_server_requests_total`

---

## Viewing Telemetry Data

### Traces

**Explore distributed traces:**
- Navigate to "Explore" → Select "Tempo"
- Search for traces by service name: `service.name="archaeopteryx"`
- Click on a trace to see the full request flow with timing breakdowns

**Example trace attributes:**
- `http.method`: GET, POST, etc.
- `http.target`: /api/v1/accounts/verify_credentials
- `http.status_code`: 200, 404, 500, etc.
- `http.duration_ms`: Request duration in milliseconds

### Logs

**Query structured logs:**
- Navigate to "Explore" → Select "Loki"
- Query: `{service_name="archaeopteryx"}`
- Filter by log level: `{service_name="archaeopteryx"} |= "error"`
- Correlate with traces using span IDs

**Example log fields:**
- `service.name`: archaeopteryx
- `service.version`: 1.0.0
- `environment`: development
- `http.method`, `http.target`, `http.status_code`
- `span_id`, `trace_id` (for correlation)

### Metrics

**Query HTTP metrics:**
- Navigate to "Explore" → Select "Prometheus"
- **Request rate**: `rate(http_server_requests_total[5m])`
- **Request duration (p95)**: `histogram_quantile(0.95, rate(http_server_request_duration_seconds_bucket[5m]))`
- **Error rate**: `rate(http_server_errors_total[5m])`
- **Active requests**: `http_server_active_requests`

**Create dashboards:**
- Import pre-built dashboards for HTTP services
- Visualize request rates, latencies, error rates
- Set up alerts for SLOs (e.g., p95 latency > 500ms)

---

##  Middleware Details

### TracingMiddleware

Automatically creates spans for every HTTP request:

```swift
router.middlewares.add(TracingMiddleware(logger: logger))
```

**Span attributes:**
- `http.method`: HTTP method
- `http.target`: Request path
- `http.scheme`: http or https
- `http.status_code`: Response status
- `http.duration_ms`: Request duration
- `http.user_agent`: User-Agent header

**Span status:**
- `ok`: 2xx-3xx responses
- `error`: 4xx-5xx responses or exceptions

### MetricsMiddleware

Collects HTTP metrics for every request:

```swift
router.middlewares.add(MetricsMiddleware(logger: logger))
```

**Metrics collected:**
- `http_server_requests_total{method,route,status}`: Counter of requests
- `http_server_request_duration_seconds{method,route,status}`: Timer for request duration
- `http_server_active_requests`: Gauge of concurrent requests
- `http_server_errors_total{method,route,status}`: Counter of errors

### LoggingMiddleware

Structured logging with trace correlation:

```swift
router.middlewares.add(LoggingMiddleware(logger: logger))
```

**Log fields:**
- `http.method`, `http.target`, `http.scheme`
- `http.status_code`, `http.duration_ms`
- `span_id`, `trace_id` (automatically injected by OTel)
- `service.name`, `service.version`, `environment`

---

## Production Considerations

### 1. **Resource Limits**

OTel can be resource-intensive. Tune batch sizes:

```swift
// In OpenTelemetrySetup.swift
let processor = OTelBatchSpanProcessor(
    exporter: exporter,
    configuration: .init(
        environment: otelEnvironment,
        maxQueueSize: 2048,        // Increase if seeing drops
        maxExportBatchSize: 512,   // Batch size for export
        scheduleDelay: .seconds(5) // Export interval
    )
)
```

### 2. **Sampling**

In high-traffic environments, sample traces:

```swift
// Sample 10% of traces
sampler: OTelConstantSampler(isOn: true, probability: 0.1)
```

### 3. **Security**

- Use TLS for OTLP endpoints in production
- Secure Grafana with authentication
- Use API keys/tokens for Grafana Cloud
- Redact sensitive data from spans and logs

### 4. **Performance**

- OTel adds ~1-5ms latency per request
- Metrics are exported every 60 seconds by default
- Traces are batched and exported every 5 seconds
- Use async exporters (default) to avoid blocking requests

---

## Troubleshooting

### OTel Not Sending Data

1. **Check OTLP_ENDPOINT is set**:
   ```bash
   echo $OTLP_ENDPOINT
   ```

2. **Verify OTel Collector is running**:
   ```bash
   curl http://localhost:8888/metrics  # Collector metrics
   ```

3. **Check Archaeopteryx logs**:
   ```bash
   swift run Archaeopteryx 2>&1 | grep otel_enabled
   # Should show: otel_enabled=true
   ```

4. **Enable debug logging in OTel Collector**:
   ```yaml
   exporters:
     logging:
       loglevel: debug
   ```

### No Traces in Grafana

- Verify Tempo is receiving traces:
  ```bash
  curl http://localhost:3200/api/search
  ```
- Check OTel Collector logs:
  ```bash
  docker-compose logs otel-collector
  ```

### No Metrics in Prometheus

- Verify Prometheus is scraping OTel Collector:
  ```bash
  curl http://localhost:9090/api/v1/targets
  ```
- Check metric names match:
  ```bash
  curl http://localhost:8889/metrics | grep http_server
  ```

---

## Example Queries

### Grafana Loki (Logs)

```logql
# All logs from Archaeopteryx
{service_name="archaeopteryx"}

# Error logs only
{service_name="archaeopteryx"} |= "level=error"

# Logs for a specific trace
{service_name="archaeopteryx"} | json | trace_id="abc123"

# Slow requests (>500ms)
{service_name="archaeopteryx"} | json | http_duration_ms > 500
```

### Grafana Tempo (Traces)

```
# Find traces by service
service.name="archaeopteryx"

# Find slow traces
duration > 500ms

# Find error traces
status=error

# Find traces for specific endpoint
http.target="/api/v1/accounts/verify_credentials"
```

### Prometheus (Metrics)

```promql
# Request rate (requests per second)
rate(http_server_requests_total[5m])

# Request rate by status code
sum by (http_status_code) (rate(http_server_requests_total[5m]))

# P95 latency
histogram_quantile(0.95,
  rate(http_server_request_duration_seconds_bucket[5m])
)

# Error rate
rate(http_server_errors_total[5m])
 /
rate(http_server_requests_total[5m])

# Active requests
http_server_active_requests
```

---

## Next Steps

1. **Set up alerts**: Configure Grafana alerts for high error rates, slow requests, etc.
2. **Create dashboards**: Build custom dashboards for monitoring Archaeopteryx
3. **Integrate with incident management**: Send alerts to PagerDuty, Slack, etc.
4. **Analyze performance**: Use traces to identify slow database queries, external API calls, etc.
5. **Correlate logs with traces**: Click on a trace span to see correlated logs

---

## Resources

- [OpenTelemetry Documentation](https://opentelemetry.io/docs/)
- [Grafana Cloud](https://grafana.com/products/cloud/)
- [swift-otel GitHub](https://github.com/swift-otel/swift-otel)
- [W3C TraceContext Specification](https://www.w3.org/TR/trace-context/)
- [OTLP Specification](https://opentelemetry.io/docs/specs/otlp/)
