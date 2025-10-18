# Docker Deployment

Deploy Archaeopteryx using Docker and Docker Compose.

## Overview

Archaeopteryx includes Docker support for local development and production deployments. Use Docker Compose for a complete stack with Redis and observability.

## Quick Start

```bash
# Build and run with Docker Compose
docker-compose up -d
```

The server will be available at `http://localhost:8080`.

## Dockerfile

The project includes a multi-stage Dockerfile:

```dockerfile
# Runtime stage - Alpine Linux
FROM alpine:3.19

# Install runtime dependencies
RUN apk add --no-cache ca-certificates libstdc++ libc6-compat libgcc

# Copy pre-built Linux binary
COPY .build/*/release/Archaeopteryx /app/

# Run as non-root
USER archaeopteryx
EXPOSE 8080

CMD ["./Archaeopteryx"]
```

## Building

### Build Swift Binary

First, build the Linux binary:

```bash
./scripts/build-linux.sh
```

This uses Docker to compile a Linux-compatible binary.

### Build Docker Image

```bash
docker build -t archaeopteryx:latest .
```

## Running

### With Docker Run

```bash
docker run -d \
  --name archaeopteryx \
  -p 8080:8080 \
  -e VALKEY_HOST=redis.example.com \
  -e VALKEY_PORT=6379 \
  -e VALKEY_PASSWORD=your-password \
  archaeopteryx:latest
```

### With Docker Compose

Create `docker-compose.yml`:

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
      ATPROTO_SERVICE_URL: https://bsky.social
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

Start the stack:

```bash
docker-compose up -d
```

## Environment Variables

Configure via environment variables:

### Required

- `VALKEY_HOST` - Redis/Valkey hostname
- `VALKEY_PORT` - Redis/Valkey port (default: 6379)

### Optional

- `HOSTNAME` - Server bind address (default: 0.0.0.0)
- `PORT` - Server port (default: 8080)
- `LOG_LEVEL` - Logging level (default: info)
- `VALKEY_PASSWORD` - Redis password (if using auth)
- `ATPROTO_SERVICE_URL` - AT Protocol service URL (default: https://bsky.social)
- `OTLP_ENDPOINT` - OpenTelemetry collector endpoint

## Production Setup

### With Observability

Add Grafana stack to `docker-compose.yml`:

```yaml
services:
  archaeopteryx:
    environment:
      OTLP_ENDPOINT: http://otel-collector:4317
      TRACING_ENABLED: "true"
      METRICS_ENABLED: "true"

  otel-collector:
    image: otel/opentelemetry-collector-contrib:latest
    ports:
      - "4317:4317"
    volumes:
      - ./otel-collector-config.yaml:/etc/otel-collector-config.yaml

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"

  tempo:
    image: grafana/tempo:latest
    ports:
      - "3200:3200"

  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
```

See <doc:OpenTelemetry> for configuration details.

### With Reverse Proxy

Use nginx for SSL termination:

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

## Health Checks

Add health check to `docker-compose.yml`:

```yaml
services:
  archaeopteryx:
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/api/v1/instance"]
      interval: 30s
      timeout: 3s
      retries: 3
      start_period: 10s
```

## Scaling

### Horizontal Scaling

Run multiple instances:

```yaml
services:
  archaeopteryx:
    build: .
    deploy:
      replicas: 3
    environment:
      VALKEY_HOST: valkey  # Shared Redis
```

Add a load balancer (nginx, HAProxy, Traefik).

### Vertical Scaling

Increase resources:

```yaml
services:
  archaeopteryx:
    deploy:
      resources:
        limits:
          memory: 2G
          cpus: '2.0'
        reservations:
          memory: 512M
          cpus: '1.0'
```

## Data Persistence

### Redis/Valkey

Configure persistence:

```yaml
services:
  valkey:
    image: valkey/valkey:7
    volumes:
      - valkey-data:/data
    command: >
      valkey-server
      --appendonly yes
      --appendfsync everysec
      --maxmemory 512mb
      --maxmemory-policy allkeys-lru
```

### Backups

Backup Redis data:

```bash
# Manual backup
docker exec valkey valkey-cli BGSAVE
docker cp valkey:/data/dump.rdb ./backups/

# Automated with cron
0 2 * * * docker exec valkey valkey-cli BGSAVE && \
  docker cp valkey:/data/dump.rdb /backups/valkey-$(date +%Y%m%d).rdb
```

## Monitoring

### Logs

View logs:

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f archaeopteryx

# Last 100 lines
docker-compose logs --tail=100 archaeopteryx
```

### Metrics

Access Prometheus: http://localhost:9090
Access Grafana: http://localhost:3000

## Troubleshooting

### Container Won't Start

Check logs:

```bash
docker-compose logs archaeopteryx
```

Common issues:
- Redis not reachable: Check `VALKEY_HOST`
- Port already in use: Change `PORT` environment variable
- Build failed: Run `./scripts/build-linux.sh` first

### Can't Connect to Redis

Test Redis connection:

```bash
docker exec -it valkey valkey-cli ping
# Should return: PONG
```

### High Memory Usage

Limit Redis memory:

```yaml
services:
  valkey:
    command: valkey-server --maxmemory 256mb --maxmemory-policy allkeys-lru
```

## Updates

### Pull Latest Code

```bash
git pull origin main
./scripts/build-linux.sh
docker-compose build
docker-compose up -d
```

### Rolling Updates

```bash
docker-compose up -d --no-deps --build archaeopteryx
```

## Security

### Best Practices

- Run as non-root user (already configured)
- Use secrets for sensitive data
- Enable Redis AUTH: `command: valkey-server --requirepass your-password`
- Use HTTPS in production (reverse proxy)
- Keep images updated: `docker-compose pull`

### Secrets Management

Use Docker secrets or environment files:

```bash
# .env file
VALKEY_PASSWORD=your-secure-password

# Reference in docker-compose.yml
env_file:
  - .env
```

Don't commit `.env` to git!

## See Also

- <doc:Fly-Deployment> - Deploy to Fly.io
- <doc:Getting-Started> - Local development
- <doc:OpenTelemetry> - Observability setup
- Complete guide: `DEPLOYMENT.md` in repository
