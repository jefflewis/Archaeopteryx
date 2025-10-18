# Fly.io Deployment

Deploy Archaeopteryx to Fly.io for production use.

## Overview

This guide covers deploying Archaeopteryx to [Fly.io](https://fly.io), a platform for running applications close to users worldwide.

## Prerequisites

- Fly.io account ([sign up](https://fly.io))
- Fly CLI installed
- Docker for building Linux binaries
- Redis provider (Upstash recommended)

### Install Fly CLI

```bash
curl -L https://fly.io/install.sh | sh
fly version
```

## Quick Deployment

```bash
# 1. Login
fly auth login

# 2. Create app
fly apps create your-app-name

# 3. Configure secrets
fly secrets set VALKEY_HOST=your-redis.upstash.io
fly secrets set VALKEY_PASSWORD=your-password

# 4. Build and deploy
./scripts/build-linux.sh
fly deploy
```

## Detailed Setup

### 1. Create Application

Edit `fly.toml` in the project root:

```toml
app = 'your-app-name'  # Change this
primary_region = 'sjc'  # Choose your region
```

Create the app:

```bash
fly apps create your-app-name
```

### 2. Set Up Redis

**Option A: Upstash (Recommended)**

1. Sign up at [upstash.com](https://upstash.com)
2. Create a Redis database
3. Note the host and password

**Option B: Fly Redis**

```bash
fly redis create
```

**Option C: Any Redis provider**

Use AWS ElastiCache, Redis Cloud, or any Redis/Valkey service.

### 3. Configure Secrets

```bash
# Required
fly secrets set VALKEY_HOST=your-redis-host.example.com
fly secrets set VALKEY_PASSWORD=your-secure-password

# Optional
fly secrets set ATPROTO_PDS_URL=https://custom-pds.example.com
```

View configured secrets:

```bash
fly secrets list
```

### 4. Build for Linux

The deployment requires a Linux binary. Build it using Docker:

```bash
./scripts/build-linux.sh
```

This script runs Swift inside a Docker container to produce a Linux-compatible binary.

### 5. Deploy

```bash
fly deploy
```

The deployment will:
1. Build a Docker image
2. Push to Fly.io
3. Run health checks
4. Route traffic

### 6. Verify

```bash
# Check status
fly status

# View logs
fly logs

# Test API
curl https://your-app.fly.dev/api/v1/instance
```

## Configuration

### Environment Variables

Set in `fly.toml` (non-sensitive only):

```toml
[env]
  HOSTNAME = "0.0.0.0"
  PORT = "8080"
  LOG_LEVEL = "info"
  ATPROTO_SERVICE_URL = "https://bsky.social"
  VALKEY_PORT = "6379"
  VALKEY_DATABASE = "0"
```

### Secrets

Set with `fly secrets set`:

| Secret | Required | Description |
|--------|----------|-------------|
| `VALKEY_HOST` | Yes | Redis hostname |
| `VALKEY_PASSWORD` | Recommended | Redis password |
| `ATPROTO_PDS_URL` | No | Custom PDS URL |

### Regions

Popular regions:

- **US West**: `sjc` (San Jose), `lax` (Los Angeles)
- **US East**: `iad` (Ashburn), `ord` (Chicago)
- **Europe**: `lhr` (London), `fra` (Frankfurt), `ams` (Amsterdam)
- **Asia**: `sin` (Singapore), `nrt` (Tokyo), `syd` (Sydney)

List all regions:

```bash
fly platform regions
```

## Scaling

### Vertical (Bigger VMs)

```bash
# Upgrade to 512MB
fly scale vm shared-cpu-2x

# Dedicated CPU with 2GB
fly scale vm performance-2x
```

VM sizes:
- `shared-cpu-1x`: 256MB (free tier)
- `shared-cpu-2x`: 512MB
- `performance-1x`: 2GB, dedicated

### Horizontal (More Instances)

```bash
# Scale to 3 instances
fly scale count 3

# Multi-region
fly scale count 2 --region sjc
fly scale count 1 --region ams
```

### Auto-scaling

Edit `fly.toml`:

```toml
[auto_scaling]
  min_machines_running = 1
  max_machines_running = 5
```

## Monitoring

### Logs

```bash
# Tail logs
fly logs

# Last 100 lines
fly logs --tail 100
```

### Metrics

View in dashboard:

```bash
fly dashboard
```

Or visit: `https://fly.io/apps/your-app/metrics`

### Health Checks

Configured in `fly.toml` to check `/api/v1/instance` every 30 seconds.

## Troubleshooting

### Build Fails

Ensure you built for Linux:

```bash
./scripts/build-linux.sh
```

### Deploy Fails

Check logs and try without health checks:

```bash
fly logs
fly deploy --no-health-checks
```

### Can't Connect to Redis

Verify secrets and test connection:

```bash
fly secrets list
fly ssh console
redis-cli -h $VALKEY_HOST -p $VALKEY_PORT -a $VALKEY_PASSWORD ping
```

### High Memory Usage

Scale up:

```bash
fly scale vm shared-cpu-2x
```

## Costs

**Free tier:**
- 3x shared-cpu-1x VMs (256MB)
- 160GB transfer/month

**Typical costs:**
- Small (1x shared-cpu-2x): ~$5-10/month
- Medium (3x shared-cpu-2x): ~$15-25/month
- Large (3x performance-2x): ~$60-80/month

**Plus Redis:**
- Upstash: Free tier available, paid from $10/month
- Fly Redis: From $2/month

[Pricing calculator](https://fly.io/docs/about/pricing/)

## CI/CD with GitHub Actions

1. Get deployment token:
   ```bash
   fly tokens create deploy
   ```

2. Add to GitHub secrets as `FLY_API_TOKEN`

3. Use the workflow template in `.github/workflows/fly-deploy.yml.template`

## Custom Domain

```bash
fly certs create your-domain.com
fly ips list
```

Then point your DNS A record to the Fly IP.

## Best Practices

- ✅ Use secrets for sensitive data
- ✅ Enable HTTPS (automatic)
- ✅ Deploy to multiple regions for global users
- ✅ Monitor logs and metrics
- ✅ Set up error tracking (Sentry)
- ✅ Back up Redis data
- ✅ Use rolling deployments

## Next Steps

- Test your deployment
- <doc:Client-Setup> to connect clients
- Set up monitoring and alerts
- Configure custom domain (optional)
- Enable auto-scaling for traffic spikes

## Resources

- [Fly.io Documentation](https://fly.io/docs)
- [Fly.io Community](https://community.fly.io)
- Complete guide: See `FLY_DEPLOYMENT.md` in the repository
