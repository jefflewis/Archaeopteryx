# Building Archaeopteryx for Docker

## Prerequisites

- Swift 6.0+ with Linux cross-compilation toolchain
- Docker and Docker Compose installed

## Build Methods

### Method 1: Using the build script (recommended)

```bash
./build-linux.sh
docker-compose build
docker-compose up -d
```

The script automatically detects your architecture and builds for Linux using SPM cross-compilation.

### Method 2: Direct SPM command

```bash
# For ARM64/aarch64
swift build -c release --triple aarch64-unknown-linux-gnu

# For x86_64
swift build -c release --triple x86_64-unknown-linux-gnu

# Then build and run Docker
docker-compose build
docker-compose up -d
```

## Output

The build produces a binary at:
- `.build/{triple}/release/Archaeopteryx`

The Dockerfile copies this binary into a minimal Alpine image (~50-80MB).

## Workflow

1. Build the Linux binary: `./build-linux.sh`
2. Build the Docker image: `docker-compose build`
3. Start the services: `docker-compose up -d`
4. View logs: `docker-compose logs -f archaeopteryx`
5. Stop: `docker-compose down`
