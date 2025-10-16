# Runtime stage - use Alpine for minimal size
FROM alpine:3.19

WORKDIR /app

# Install runtime dependencies
RUN apk add --no-cache \
    ca-certificates \
    libstdc++ \
    libc6-compat \
    libgcc

# Copy the pre-built executable
# Build script places it in .build/{triple}/release/Archaeopteryx
COPY .build/*/release/Archaeopteryx /app/

# Create a non-root user for running the app
RUN adduser -D -u 1000 archaeopteryx && \
    chown -R archaeopteryx:archaeopteryx /app

USER archaeopteryx

EXPOSE 8080

CMD ["./Archaeopteryx"]
