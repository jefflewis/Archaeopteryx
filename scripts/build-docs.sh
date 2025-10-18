#!/bin/bash
# Build DocC documentation for Archaeopteryx
# Generates a static documentation website

set -e

echo "📚 Building Archaeopteryx Documentation..."
echo ""

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
TARGET="Archaeopteryx"
DOCS_DIR="./docs"

# Parse arguments
HOSTING_BASE_PATH=""
TRANSFORM_FOR_STATIC="false"

while [[ $# -gt 0 ]]; do
    case $1 in
        --hosting-base-path)
            HOSTING_BASE_PATH="$2"
            TRANSFORM_FOR_STATIC="true"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--hosting-base-path PATH]"
            exit 1
            ;;
    esac
done

# Clean previous build
if [ -d "$DOCS_DIR" ]; then
    echo -e "${BLUE}Cleaning previous build...${NC}"
    rm -rf "$DOCS_DIR"
fi

# Build documentation
echo -e "${BLUE}Building documentation for target: $TARGET${NC}"
echo ""

if [ "$TRANSFORM_FOR_STATIC" = "true" ]; then
    echo -e "${YELLOW}Building for static hosting with base path: $HOSTING_BASE_PATH${NC}"
    swift package --allow-writing-to-directory "$DOCS_DIR" \
        generate-documentation \
        --target "$TARGET" \
        --disable-indexing \
        --transform-for-static-hosting \
        --hosting-base-path "$HOSTING_BASE_PATH" \
        --output-path "$DOCS_DIR"
else
    echo -e "${YELLOW}Building for local preview${NC}"
    swift package --allow-writing-to-directory "$DOCS_DIR" \
        generate-documentation \
        --target "$TARGET" \
        --output-path "$DOCS_DIR"
fi

echo ""
echo -e "${GREEN}✓ Documentation built successfully!${NC}"
echo ""
echo -e "${GREEN}Output directory:${NC} $DOCS_DIR"

# Show size
if [ -d "$DOCS_DIR" ]; then
    SIZE=$(du -sh "$DOCS_DIR" | cut -f1)
    echo -e "${GREEN}Total size:${NC} $SIZE"
fi

echo ""

if [ "$TRANSFORM_FOR_STATIC" = "true" ]; then
    echo -e "${GREEN}Ready to deploy!${NC}"
    echo "Documentation URL will be:"
    echo "  https://<username>.github.io/$HOSTING_BASE_PATH/documentation/$TARGET"
else
    echo -e "${GREEN}To preview locally:${NC}"
    echo "  ./scripts/preview-docs.sh"
fi

echo ""
