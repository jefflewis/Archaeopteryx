# Deployment

Production deployment guide.

## Docker Quick Start

```dockerfile
# Dockerfile
FROM swift:6.0-jammy
WORKDIR /app
COPY . .
RUN swift build -c release
EXPOSE 8080
CMD [".build/release/Archaeopteryx"]
```

```bash
docker build -t archaeopteryx .
docker run -p 8080:8080 \
  -e VALKEY_HOST=redis.example.com \
  archaeopteryx
```

## Docker Compose

### Basic

```yaml
version: '3.8'

services:
  archaeopteryx:
    build: .
    ports:
      - "8080:8080"
    environment:
      HOSTNAME: 0.0.0.0
      PORT: 8080
      VALKEY_HOST: valkey
      VALKEY_PORT: 6379
      LOG_LEVEL: info
    depends_on:
      - valkey
    restart: unless-stopped

  valkey:
    image: valkey/valkey:7
    volumes:
      - valkey-data:/data
    command: valkey-server --appendonly yes
    restart: unless-stopped

volumes:
  valkey-data:
```

```bash
docker-compose up -d
```

### With Observability

Add to compose file:

```yaml
  tempo:
    image: grafana/tempo:latest
    ports:
      - "4317:4317"
    volumes:
      - ./tempo.yaml:/etc/tempo.yaml

  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
```

Set in archaeopteryx service:

```yaml
    environment:
      OTEL_EXPORTER_OTLP_ENDPOINT: http://tempo:4317
      OTEL_TRACES_ENABLED: "true"
      OTEL_METRICS_ENABLED: "true"
```

See [OPENTELEMETRY.md](OPENTELEMETRY.md) for config files.

## Environment Variables

### Required

```bash
HOSTNAME=0.0.0.0
PORT=8080
VALKEY_HOST=localhost
VALKEY_PORT=6379
ATPROTO_SERVICE_URL=https://bsky.social
LOG_LEVEL=info
```

### Optional

```bash
VALKEY_PASSWORD=              # If using auth
VALKEY_DATABASE=0
ATPROTO_PDS_URL=              # Custom PDS
OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4317
OTEL_TRACES_ENABLED=true
OTEL_METRICS_ENABLED=true
```

## Reverse Proxy (nginx)

```nginx
server {
    listen 443 ssl http2;
    server_name archaeopteryx.example.com;

    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```

## Health Check

```bash
curl http://localhost:8080/api/v1/instance
# Should return 200 OK with JSON
```

Docker health check:

```yaml
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/api/v1/instance"]
      interval: 30s
      timeout: 3s
      retries: 3
```

## Production Checklist

### Security
- [ ] Use HTTPS (cert via Let's Encrypt)
- [ ] Set VALKEY_PASSWORD
- [ ] Firewall Redis port (6379)
- [ ] Run as non-root user
- [ ] Enable rate limiting (default: on)

### Performance
- [ ] Use release build (`swift build -c release`)
- [ ] Configure Valkey maxmemory
- [ ] Set resource limits
- [ ] Enable caching headers

### Observability
- [ ] Set LOG_LEVEL=info (not debug)
- [ ] Enable OpenTelemetry
- [ ] Monitor /api/v1/instance
- [ ] Set up alerts

### Reliability
- [ ] Backup Valkey data
- [ ] Configure Valkey persistence
- [ ] Use health checks
- [ ] Test failover

## Valkey Config

Production settings:

```bash
# In redis.conf or valkey.conf
maxmemory 512mb
maxmemory-policy allkeys-lru
appendonly yes
appendfsync everysec
save 900 1
save 300 10
```

## Scaling

### Horizontal

Run multiple instances, shared Valkey:

```yaml
services:
  archaeopteryx:
    build: .
    deploy:
      replicas: 3
    environment:
      VALKEY_HOST: valkey
```

Add load balancer (nginx, HAProxy, etc).

### Vertical

Increase resources:

```yaml
    deploy:
      resources:
        limits:
          memory: 2G
          cpus: '2.0'
```

## Backup

### Valkey RDB

```bash
# Manual backup
docker exec valkey valkey-cli BGSAVE
cp /var/lib/docker/volumes/valkey-data/_data/dump.rdb /backups/

# Cron daily
0 2 * * * docker exec valkey valkey-cli BGSAVE
```

### Volume Backup

```bash
docker run --rm \
  -v archaeopteryx_valkey-data:/data \
  -v $(pwd)/backups:/backup \
  alpine tar czf /backup/valkey-$(date +%Y%m%d).tar.gz /data
```

## Monitoring

### Key Metrics

```promql
# Request rate
rate(http_server_requests_total[5m])

# Error rate
rate(http_server_errors_total[5m]) / rate(http_server_requests_total[5m])

# P95 latency
histogram_quantile(0.95, rate(http_server_request_duration_seconds_bucket[5m]))
```

### Alerts

- Error rate > 5%
- P95 latency > 1s
- Cache hit ratio < 80%
- Instance down

## Troubleshooting

### Connection Refused (Redis)

```bash
redis-cli ping  # Should return PONG
docker logs valkey
```

### High Memory

```bash
# Check Redis memory
redis-cli INFO memory

# Set limit
redis-cli CONFIG SET maxmemory 256mb
```

### Slow Responses

- Check Redis latency: `redis-cli --latency`
- Check Bluesky API status
- Increase cache TTLs
- Add more instances

### Build Fails

```bash
export DOCKER_BUILDKIT=1
docker build --no-cache -t archaeopteryx .
```

## Kubernetes

Basic deployment:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: archaeopteryx
spec:
  replicas: 3
  template:
    spec:
      containers:
      - name: archaeopteryx
        image: archaeopteryx:latest
        env:
        - name: VALKEY_HOST
          value: valkey
        ports:
        - containerPort: 8080
        livenessProbe:
          httpGet:
            path: /api/v1/instance
            port: 8080
```

See production k8s examples at kubernetes/ directory.

## Performance Targets

- Account endpoints: p95 < 200ms
- Timeline endpoints: p95 < 500ms
- Throughput: 100+ req/sec
- Cache hit: >90% profiles

## Support

See [README.md](README.md) for support channels.
