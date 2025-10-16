#!/bin/bash
set -e

echo "Building Archaeopteryx for Linux..."

# Detect architecture
ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ] || [ "$ARCH" = "aarch64" ]; then
    SWIFT_TRIPLE="aarch64-unknown-linux-gnu"
else
    SWIFT_TRIPLE="x86_64-unknown-linux-gnu"
fi

echo "Building for: $SWIFT_TRIPLE"

# Build using Swift cross-compilation
swift build -c release --triple $SWIFT_TRIPLE

echo "Build complete! Binary available at .build/$SWIFT_TRIPLE/release/Archaeopteryx"
echo "Now you can run: docker-compose build && docker-compose up -d"
