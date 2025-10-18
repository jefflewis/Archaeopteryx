#!/bin/bash
# Build Archaeopteryx for Linux deployment (x86_64)
# This is required before deploying to Fly.io or other Linux-based platforms

set -e

echo "🔨 Building Archaeopteryx for Linux (x86_64)..."
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Clean previous builds
echo -e "${BLUE}Cleaning previous builds...${NC}"
rm -rf .build/x86_64-unknown-linux-gnu
echo ""

# Build using Docker with Swift 6.0
echo -e "${BLUE}Building with Swift 6.0 in Docker...${NC}"
echo "This may take several minutes on first run (downloads dependencies)"
echo ""

docker run --rm \
  -v "$(pwd):/workspace" \
  -w /workspace \
  swift:6.0-jammy \
  swift build -c release \
    --static-swift-stdlib \
    --build-path /workspace/.build

echo ""
echo -e "${GREEN}✓ Build complete!${NC}"
echo ""

# Verify the binary exists
BINARY_PATH=".build/x86_64-unknown-linux-gnu/release/Archaeopteryx"
if [ -f "$BINARY_PATH" ]; then
    echo -e "${GREEN}✓ Binary created:${NC} $BINARY_PATH"

    # Show binary size
    BINARY_SIZE=$(ls -lh "$BINARY_PATH" | awk '{print $5}')
    echo -e "${GREEN}✓ Size:${NC} $BINARY_SIZE"

    # Verify it's a Linux binary
    file "$BINARY_PATH"

    echo ""
    echo -e "${GREEN}Ready to deploy!${NC}"
    echo "Run: fly deploy"
else
    echo "❌ Error: Binary not found at $BINARY_PATH"
    exit 1
fi
