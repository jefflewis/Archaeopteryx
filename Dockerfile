# Build stage - use Swift builder image
FROM swift:latest AS builder

WORKDIR /build

# Copy package manifest files
COPY Package.swift Package.resolved ./

# Copy source code
COPY Sources ./Sources
COPY Tests ./Tests

# Build the application in release mode
RUN swift build -c release

# Runtime stage - use Ubuntu for better Swift compatibility
FROM ubuntu:noble-20241011

WORKDIR /app

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates \
    libcurl4 \
    libxml2 \
    libicu74 \
    tzdata \
    && rm -rf /var/lib/apt/lists/*

# Copy Swift runtime libraries from builder
COPY --from=builder /usr/lib/swift /usr/lib/swift

# Copy the built executable from builder stage
COPY --from=builder /build/.build/release/Archaeopteryx /app/

# Create a non-root user for running the app (let system assign UID)
RUN useradd -m -s /bin/bash archaeopteryx && \
    chown -R archaeopteryx:archaeopteryx /app

USER archaeopteryx

EXPOSE 8080

CMD ["./Archaeopteryx"]
