#!/bin/bash
# Preview DocC documentation locally
# Starts a local web server to preview the documentation

set -e

echo "📖 Previewing Archaeopteryx Documentation..."
echo ""

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
TARGET="Archaeopteryx"

# Check if documentation is built
if [ ! -d "./docs" ]; then
    echo -e "${YELLOW}Documentation not built yet. Building now...${NC}"
    echo ""
    ./scripts/build-docs.sh
    echo ""
fi

# Use Swift's built-in preview server
echo -e "${BLUE}Starting preview server...${NC}"
echo ""
echo -e "${GREEN}Documentation will be available at:${NC}"
echo "  http://localhost:8000/documentation/$TARGET"
echo ""
echo -e "${YELLOW}Press Ctrl+C to stop the server${NC}"
echo ""

swift package --disable-sandbox preview-documentation --target "$TARGET"
