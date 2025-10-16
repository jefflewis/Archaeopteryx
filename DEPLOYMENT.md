# Archaeopteryx Deployment Guide

This guide covers deploying Archaeopteryx in various environments, from development to production.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Local Development](#local-development)
3. [Docker Deployment](#docker-deployment)
4. [Docker Compose](#docker-compose)
5. [Kubernetes](#kubernetes)
6. [Production Checklist](#production-checklist)
7. [Monitoring & Observability](#monitoring--observability)
8. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required

- **Swift 6.0+** (for building from source)
- **Redis or Valkey** (for caching and rate limiting)
- **Bluesky Account** (for testing)

### Recommended for Production

- **Reverse Proxy** (nginx, Caddy, Traefik) for TLS termination
- **Grafana Stack** (Tempo, Loki, Prometheus) for observability
- **Process Manager** (systemd, Docker, Kubernetes) for service management
- **Load Balancer** (if running multiple instances)

---

## Local Development

### 1. Install Dependencies

**macOS**:
```bash
# Install Swift (if not already installed via Xcode)
xcode-select --install

# Install Redis
brew install redis
brew services start redis
```

**Linux (Ubuntu/Debian)**:
```bash
# Install Swift
wget https://swift.org/builds/swift-6.0-release/ubuntu2204/swift-6.0-RELEASE/swift-6.0-RELEASE-ubuntu22.04.tar.gz
tar xzf swift-6.0-RELEASE-ubuntu22.04.tar.gz
sudo mv swift-6.0-RELEASE-ubuntu22.04 /usr/share/swift
echo 'export PATH="/usr/share/swift/usr/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# Install Redis
sudo apt update
sudo apt install redis-server
sudo systemctl start redis
```

### 2. Clone and Build

```bash
git clone https://github.com/yourusername/Archaeopteryx.git
cd Archaeopteryx
swift build
```

### 3. Configure Environment

Create `.env` file in project root:

```bash
# Server
HOSTNAME=0.0.0.0
PORT=8080

# Cache
VALKEY_HOST=localhost
VALKEY_PORT=6379
VALKEY_PASSWORD=
VALKEY_DATABASE=0

# AT Protocol
ATPROTO_SERVICE_URL=https://bsky.social

# Logging
LOG_LEVEL=debug
```

### 4. Run

```bash
# Source environment variables
export $(cat .env | xargs)

# Run in debug mode
swift run Archaeopteryx

# Or build and run release binary
swift build -c release
.build/release/Archaeopteryx
```

### 5. Test

```bash
# Check health
curl http://localhost:8080/api/v1/instance

# Should return JSON with instance metadata
```

---

## Docker Deployment

### Option 1: Pre-built Image (when available)

```bash
docker pull archaeopteryx/archaeopteryx:latest

docker run -d \
  --name archaeopteryx \
  -p 8080:8080 \
  -e VALKEY_HOST=host.docker.internal \
  -e LOG_LEVEL=info \
  archaeopteryx/archaeopteryx:latest
```

### Option 2: Build from Source

**Create `Dockerfile`**:

```dockerfile
# Multi-stage build for smaller final image
FROM swift:6.0 AS builder

WORKDIR /build

# Copy package files first (for layer caching)
COPY Package.swift Package.resolved ./
COPY Sources ./Sources

# Build release binary
RUN swift build -c release \
    --static-swift-stdlib \
    -Xlinker -s

# Production image
FROM ubuntu:22.04

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    libcurl4 \
    libxml2 \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN useradd -m -s /bin/bash archaeopteryx

WORKDIR /app

# Copy binary from builder
COPY --from=builder /build/.build/release/Archaeopteryx ./archaeopteryx

# Change ownership
RUN chown -R archaeopteryx:archaeopteryx /app

# Switch to non-root user
USER archaeopteryx

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s \
  CMD curl -f http://localhost:8080/api/v1/instance || exit 1

# Run
CMD ["./archaeopteryx"]
```

**Build and Run**:

```bash
# Build image
docker build -t archaeopteryx:local .

# Run container
docker run -d \
  --name archaeopteryx \
  -p 8080:8080 \
  -e HOSTNAME=0.0.0.0 \
  -e PORT=8080 \
  -e VALKEY_HOST=valkey \
  -e VALKEY_PORT=6379 \
  -e LOG_LEVEL=info \
  -e ATPROTO_SERVICE_URL=https://bsky.social \
  --restart unless-stopped \
  archaeopteryx:local
```

### Docker with Local Redis

```bash
# Create network
docker network create archaeopteryx-net

# Run Redis
docker run -d \
  --name valkey \
  --network archaeopteryx-net \
  -p 6379:6379 \
  valkey/valkey:latest

# Run Archaeopteryx
docker run -d \
  --name archaeopteryx \
  --network archaeopteryx-net \
  -p 8080:8080 \
  -e VALKEY_HOST=valkey \
  -e VALKEY_PORT=6379 \
  archaeopteryx:local
```

---

## Docker Compose

### Basic Setup

Create `docker-compose.yml`:

```yaml
version: '3.8'

services:
  archaeopteryx:
    build: .
    container_name: archaeopteryx
    ports:
      - "8080:8080"
    environment:
      - HOSTNAME=0.0.0.0
      - PORT=8080
      - VALKEY_HOST=valkey
      - VALKEY_PORT=6379
      - LOG_LEVEL=info
      - ATPROTO_SERVICE_URL=https://bsky.social
    depends_on:
      valkey:
        condition: service_healthy
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/api/v1/instance"]
      interval: 30s
      timeout: 3s
      retries: 3
      start_period: 10s

  valkey:
    image: valkey/valkey:latest
    container_name: valkey
    ports:
      - "6379:6379"
    volumes:
      - valkey-data:/data
    command: >
      valkey-server
      --appendonly yes
      --maxmemory 256mb
      --maxmemory-policy allkeys-lru
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "valkey-cli", "ping"]
      interval: 10s
      timeout: 3s
      retries: 3

volumes:
  valkey-data:
    driver: local
```

**Run**:

```bash
# Start services
docker compose up -d

# View logs
docker compose logs -f

# Stop services
docker compose down

# Stop and remove volumes
docker compose down -v
```

### Production Setup with Nginx

Create `docker-compose.prod.yml`:

```yaml
version: '3.8'

services:
  archaeopteryx:
    build: .
    container_name: archaeopteryx
    expose:
      - "8080"
    environment:
      - HOSTNAME=0.0.0.0
      - PORT=8080
      - VALKEY_HOST=valkey
      - VALKEY_PORT=6379
      - LOG_LEVEL=info
      - ATPROTO_SERVICE_URL=https://bsky.social
      - OTEL_EXPORTER_OTLP_ENDPOINT=http://tempo:4317
      - OTEL_TRACES_ENABLED=true
      - OTEL_METRICS_ENABLED=true
    depends_on:
      valkey:
        condition: service_healthy
    restart: unless-stopped
    networks:
      - archaeopteryx-net

  valkey:
    image: valkey/valkey:latest
    container_name: valkey
    volumes:
      - valkey-data:/data
    command: >
      valkey-server
      --appendonly yes
      --maxmemory 512mb
      --maxmemory-policy allkeys-lru
    restart: unless-stopped
    networks:
      - archaeopteryx-net
    healthcheck:
      test: ["CMD", "valkey-cli", "ping"]
      interval: 10s
      timeout: 3s
      retries: 3

  nginx:
    image: nginx:alpine
    container_name: nginx
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./certs:/etc/nginx/certs:ro
    depends_on:
      - archaeopteryx
    restart: unless-stopped
    networks:
      - archaeopteryx-net

networks:
  archaeopteryx-net:
    driver: bridge

volumes:
  valkey-data:
    driver: local
```

**Create `nginx.conf`**:

```nginx
events {
    worker_connections 1024;
}

http {
    upstream archaeopteryx {
        server archaeopteryx:8080;
    }

    # Rate limiting
    limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;

    server {
        listen 80;
        server_name archaeopteryx.example.com;

        # Redirect to HTTPS
        return 301 https://$server_name$request_uri;
    }

    server {
        listen 443 ssl http2;
        server_name archaeopteryx.example.com;

        # TLS configuration
        ssl_certificate /etc/nginx/certs/fullchain.pem;
        ssl_certificate_key /etc/nginx/certs/privkey.pem;
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers HIGH:!aNULL:!MD5;
        ssl_prefer_server_ciphers on;

        # Security headers
        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header X-Frame-Options "DENY" always;
        add_header X-XSS-Protection "1; mode=block" always;

        # Proxy settings
        location / {
            proxy_pass http://archaeopteryx;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;

            # Rate limiting
            limit_req zone=api burst=20 nodelay;

            # Timeouts
            proxy_connect_timeout 5s;
            proxy_send_timeout 60s;
            proxy_read_timeout 60s;

            # Buffering
            proxy_buffering on;
            proxy_buffer_size 4k;
            proxy_buffers 8 4k;
        }

        # Health check endpoint (no rate limiting)
        location /api/v1/instance {
            proxy_pass http://archaeopteryx;
            proxy_set_header Host $host;
        }
    }
}
```

**Run**:

```bash
docker compose -f docker-compose.prod.yml up -d
```

---

## Kubernetes

### Basic Deployment

**Create `kubernetes/namespace.yaml`**:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: archaeopteryx
```

**Create `kubernetes/valkey.yaml`**:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: valkey
  namespace: archaeopteryx
spec:
  ports:
    - port: 6379
      targetPort: 6379
  selector:
    app: valkey
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: valkey
  namespace: archaeopteryx
spec:
  replicas: 1
  selector:
    matchLabels:
      app: valkey
  template:
    metadata:
      labels:
        app: valkey
    spec:
      containers:
        - name: valkey
          image: valkey/valkey:latest
          ports:
            - containerPort: 6379
          volumeMounts:
            - name: valkey-data
              mountPath: /data
          resources:
            requests:
              memory: "256Mi"
              cpu: "100m"
            limits:
              memory: "512Mi"
              cpu: "500m"
      volumes:
        - name: valkey-data
          persistentVolumeClaim:
            claimName: valkey-pvc
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: valkey-pvc
  namespace: archaeopteryx
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
```

**Create `kubernetes/archaeopteryx.yaml`**:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: archaeopteryx-config
  namespace: archaeopteryx
data:
  HOSTNAME: "0.0.0.0"
  PORT: "8080"
  VALKEY_HOST: "valkey"
  VALKEY_PORT: "6379"
  LOG_LEVEL: "info"
  ATPROTO_SERVICE_URL: "https://bsky.social"
---
apiVersion: v1
kind: Service
metadata:
  name: archaeopteryx
  namespace: archaeopteryx
spec:
  type: LoadBalancer
  ports:
    - port: 80
      targetPort: 8080
  selector:
    app: archaeopteryx
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: archaeopteryx
  namespace: archaeopteryx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: archaeopteryx
  template:
    metadata:
      labels:
        app: archaeopteryx
    spec:
      containers:
        - name: archaeopteryx
          image: archaeopteryx/archaeopteryx:latest
          ports:
            - containerPort: 8080
          envFrom:
            - configMapRef:
                name: archaeopteryx-config
          livenessProbe:
            httpGet:
              path: /api/v1/instance
              port: 8080
            initialDelaySeconds: 10
            periodSeconds: 30
          readinessProbe:
            httpGet:
              path: /api/v1/instance
              port: 8080
            initialDelaySeconds: 5
            periodSeconds: 10
          resources:
            requests:
              memory: "256Mi"
              cpu: "250m"
            limits:
              memory: "512Mi"
              cpu: "1000m"
```

**Deploy**:

```bash
# Create namespace
kubectl apply -f kubernetes/namespace.yaml

# Deploy Valkey
kubectl apply -f kubernetes/valkey.yaml

# Deploy Archaeopteryx
kubectl apply -f kubernetes/archaeopteryx.yaml

# Check status
kubectl get pods -n archaeopteryx

# View logs
kubectl logs -f deployment/archaeopteryx -n archaeopteryx

# Get service URL
kubectl get svc archaeopteryx -n archaeopteryx
```

### Horizontal Pod Autoscaler

**Create `kubernetes/hpa.yaml`**:

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: archaeopteryx-hpa
  namespace: archaeopteryx
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: archaeopteryx
  minReplicas: 2
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 80
```

```bash
kubectl apply -f kubernetes/hpa.yaml
```

---

## Production Checklist

### Security

- [ ] **Use HTTPS** - TLS certificates from Let's Encrypt or your CA
- [ ] **Strong Redis Password** - Set `VALKEY_PASSWORD` environment variable
- [ ] **Firewall Rules** - Restrict access to Redis port (6379)
- [ ] **Non-Root User** - Run Archaeopteryx as non-root user
- [ ] **Security Headers** - Configure via reverse proxy (HSTS, CSP, etc.)
- [ ] **Rate Limiting** - Enable RateLimitMiddleware (default: enabled)
- [ ] **DDoS Protection** - Use Cloudflare or similar service
- [ ] **Regular Updates** - Keep dependencies up to date

### Performance

- [ ] **Resource Limits** - Set appropriate memory/CPU limits
- [ ] **Connection Pooling** - Redis connection pool size (default: 10)
- [ ] **Cache Configuration** - Tune cache TTLs for your use case
- [ ] **Horizontal Scaling** - Run multiple instances behind load balancer
- [ ] **CDN** - Cache static assets if serving web UI
- [ ] **Database Indices** - If using persistent storage (future enhancement)

### Observability

- [ ] **Structured Logging** - Enable JSON logging for production
- [ ] **Metrics** - Export to Prometheus or Grafana
- [ ] **Tracing** - Enable OpenTelemetry for distributed tracing
- [ ] **Alerting** - Set up alerts for errors, high latency, downtime
- [ ] **Health Checks** - Monitor `/api/v1/instance` endpoint
- [ ] **Log Aggregation** - Send logs to Loki, Elasticsearch, or similar

### Reliability

- [ ] **Backups** - Regular Redis backups (RDB or AOF)
- [ ] **Monitoring** - Uptime monitoring (UptimeRobot, Pingdom, etc.)
- [ ] **Failover** - Redis Sentinel or Redis Cluster for high availability
- [ ] **Load Balancing** - Distribute traffic across multiple instances
- [ ] **Graceful Shutdown** - Handle SIGTERM properly (built-in)
- [ ] **Circuit Breakers** - Protect against upstream API failures

### Configuration

- [ ] **Environment Variables** - All secrets in environment, not config files
- [ ] **Log Level** - Set to `info` or `warning` in production (not `debug`)
- [ ] **Cache Size** - Tune Redis maxmemory based on instance count
- [ ] **Rate Limits** - Adjust per your usage patterns
- [ ] **Timeouts** - Configure appropriate request/response timeouts

---

## Monitoring & Observability

### Grafana Stack (Recommended)

See [OPENTELEMETRY.md](OPENTELEMETRY.md) for complete setup instructions.

**Quick Start**:

```bash
# Clone Grafana stack
git clone https://github.com/grafana/intro-to-mlt
cd intro-to-mlt

# Start Grafana, Tempo, Loki, Prometheus
docker compose up -d

# Configure Archaeopteryx
export OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4317
export OTEL_TRACES_ENABLED=true
export OTEL_METRICS_ENABLED=true

# Run Archaeopteryx
./archaeopteryx
```

**Access**:
- Grafana: http://localhost:3000 (admin/admin)
- Prometheus: http://localhost:9090
- Tempo: http://localhost:3200

### Prometheus Metrics

Archaeopteryx exposes Prometheus-compatible metrics:

```bash
# Scrape metrics (if using Prometheus exporter)
curl http://localhost:8080/metrics
```

**Key Metrics**:
- `http_server_requests_total` - Total requests by method, route, status
- `http_server_request_duration_seconds` - Request latency histogram
- `http_server_active_requests` - Active requests gauge
- `http_server_errors_total` - Total errors by type

### Health Checks

```bash
# Basic health check
curl http://localhost:8080/api/v1/instance

# Expected response: 200 OK with JSON
```

### Logging

**Structured Logging** (JSON format):

```bash
# Enable JSON logging for production
export LOG_FORMAT=json
```

**Log Levels**:
- `trace` - Very verbose, debug only
- `debug` - Detailed information
- `info` - General information (recommended for production)
- `notice` - Important events
- `warning` - Warning messages
- `error` - Error messages
- `critical` - Critical errors

---

## Troubleshooting

### Common Issues

#### 1. Connection Refused (Redis)

**Symptom**: `Error: Connection refused to localhost:6379`

**Solutions**:
```bash
# Check if Redis is running
redis-cli ping
# Should return: PONG

# Start Redis
brew services start redis  # macOS
sudo systemctl start redis # Linux
docker start valkey        # Docker

# Check Redis configuration
redis-cli config get bind
redis-cli config get protected-mode
```

#### 2. High Memory Usage

**Symptom**: Archaeopteryx using excessive memory

**Solutions**:
```bash
# Configure Redis maxmemory
redis-cli CONFIG SET maxmemory 256mb
redis-cli CONFIG SET maxmemory-policy allkeys-lru

# Restart Archaeopteryx with lower cache TTLs
# (Reduces cache size at cost of more API calls)
```

#### 3. Slow Response Times

**Symptom**: API responses taking > 1 second

**Solutions**:
- Check Redis latency: `redis-cli --latency`
- Check Bluesky API status
- Increase cache TTLs to reduce upstream calls
- Add more instances behind load balancer
- Check network latency to Bluesky API

#### 4. Rate Limit Errors

**Symptom**: `429 Too Many Requests`

**Solutions**:
```bash
# Increase rate limits (environment variables)
export RATE_LIMIT_UNAUTHENTICATED=600  # 600 req/5min
export RATE_LIMIT_AUTHENTICATED=2000   # 2000 req/5min

# Or disable rate limiting (not recommended)
# Edit App.swift to remove RateLimitMiddleware
```

#### 5. Docker Build Fails

**Symptom**: Docker build errors

**Solutions**:
```bash
# Use buildkit for better caching
export DOCKER_BUILDKIT=1
docker build -t archaeopteryx:local .

# Increase Docker memory limit
# Docker Desktop → Settings → Resources → Memory (8GB+)

# Use multi-stage build to reduce image size
# (Already configured in Dockerfile)
```

### Debug Mode

```bash
# Enable verbose logging
export LOG_LEVEL=trace

# Run Archaeopteryx
./archaeopteryx

# You'll see detailed logs for every request
```

### Getting Help

- **GitHub Issues**: https://github.com/yourusername/Archaeopteryx/issues
- **Discussions**: https://github.com/yourusername/Archaeopteryx/discussions
- **Bluesky**: [@archaeopteryx.dev](https://bsky.app/profile/archaeopteryx.dev)

---

## Performance Tuning

### Redis Configuration

**For Production** (`redis.conf`):

```conf
# Memory
maxmemory 512mb
maxmemory-policy allkeys-lru

# Persistence (choose one)
# Option 1: RDB snapshots
save 900 1
save 300 10
save 60 10000

# Option 2: AOF (more durable)
appendonly yes
appendfsync everysec

# Networking
tcp-backlog 511
timeout 0
tcp-keepalive 300

# Performance
lazyfree-lazy-eviction yes
lazyfree-lazy-expire yes
```

### Archaeopteryx Tuning

**Environment Variables**:

```bash
# Increase cache TTLs (reduces API calls)
CACHE_PROFILE_TTL=1800     # 30 minutes
CACHE_POST_TTL=600         # 10 minutes
CACHE_TIMELINE_TTL=300     # 5 minutes

# Adjust rate limits
RATE_LIMIT_UNAUTHENTICATED=300
RATE_LIMIT_AUTHENTICATED=1000

# Connection pooling
VALKEY_POOL_SIZE=20        # Increase for high traffic
```

### Load Testing

**Using k6**:

```javascript
// load-test.js
import http from 'k6/http';
import { check, sleep } from 'k6';

export let options = {
  vus: 10,
  duration: '30s',
};

export default function () {
  let response = http.get('http://localhost:8080/api/v1/instance');
  check(response, {
    'status is 200': (r) => r.status === 200,
    'response time < 200ms': (r) => r.timings.duration < 200,
  });
  sleep(1);
}
```

```bash
# Run load test
k6 run load-test.js
```

---

## Backup & Recovery

### Redis Backups

**RDB Snapshots**:

```bash
# Manual backup
redis-cli BGSAVE

# Copy RDB file
cp /var/lib/redis/dump.rdb /backup/dump-$(date +%Y%m%d).rdb
```

**AOF Backups**:

```bash
# AOF is continuously written
# Copy AOF file
cp /var/lib/redis/appendonly.aof /backup/appendonly-$(date +%Y%m%d).aof
```

### Docker Volume Backups

```bash
# Backup Valkey volume
docker run --rm \
  -v archaeopteryx_valkey-data:/data \
  -v $(pwd)/backups:/backup \
  alpine tar czf /backup/valkey-backup-$(date +%Y%m%d).tar.gz /data
```

### Restore

```bash
# Stop services
docker compose down

# Restore backup
docker run --rm \
  -v archaeopteryx_valkey-data:/data \
  -v $(pwd)/backups:/backup \
  alpine tar xzf /backup/valkey-backup-20241014.tar.gz -C /

# Start services
docker compose up -d
```

---

## Scaling Strategies

### Vertical Scaling

- Increase CPU/memory for single instance
- Optimize Redis memory limits
- Tune cache TTLs and connection pools

### Horizontal Scaling

- Run multiple Archaeopteryx instances
- Load balancer (nginx, HAProxy, Kubernetes Ingress)
- Shared Redis/Valkey instance (or Redis Cluster)
- Session affinity not required (stateless)

### Redis Scaling

- **Redis Sentinel** - High availability with automatic failover
- **Redis Cluster** - Distributed cache across multiple nodes
- **Managed Redis** - AWS ElastiCache, Azure Cache, Google Memorystore

---

Last Updated: 2025-10-14
