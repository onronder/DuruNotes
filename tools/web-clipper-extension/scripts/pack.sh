#!/bin/bash

# DuruNotes Web Clipper - Packaging Script
# Creates a Chrome Web Store ready .zip file

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
EXTENSION_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="$EXTENSION_DIR/dist"
OUTPUT_FILE="$DIST_DIR/web-clipper.zip"
VERSION=$(grep '"version"' "$EXTENSION_DIR/manifest.json" | sed 's/.*"version": "\(.*\)".*/\1/')

echo -e "${GREEN}🚀 DuruNotes Web Clipper Packaging Script${NC}"
echo -e "Extension Directory: $EXTENSION_DIR"
echo -e "Version: ${YELLOW}$VERSION${NC}"
echo ""

# Create dist directory if it doesn't exist
if [ ! -d "$DIST_DIR" ]; then
    echo "Creating dist directory..."
    mkdir -p "$DIST_DIR"
fi

# Remove old zip if it exists
if [ -f "$OUTPUT_FILE" ]; then
    echo "Removing old package..."
    rm "$OUTPUT_FILE"
fi

# Change to extension directory
cd "$EXTENSION_DIR"

# Validate required files exist
echo "Validating extension files..."
REQUIRED_FILES=(
    "manifest.json"
    "background.js"
    "popup.html"
    "popup.js"
    "icons/icon-16.png"
    "icons/icon-48.png"
    "icons/icon-128.png"
)

MISSING_FILES=()
for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        MISSING_FILES+=("$file")
    fi
done

if [ ${#MISSING_FILES[@]} -gt 0 ]; then
    echo -e "${RED}❌ Missing required files:${NC}"
    for file in "${MISSING_FILES[@]}"; do
        echo -e "  - $file"
    done
    exit 1
fi

echo -e "${GREEN}✓${NC} All required files present"

# Create the zip file
echo ""
echo "Creating package..."
zip -r "$OUTPUT_FILE" . \
    -x "store/*" \
    -x "scripts/*" \
    -x "dist/*" \
    -x "*.zip" \
    -x ".*" \
    -x "*~" \
    -x "*.bak" \
    -x "*.swp" \
    -x "node_modules/*" \
    -x "package*.json" \
    -x ".git/*" \
    -x ".gitignore" \
    -x "README.md.bak" \
    -x "*.log" \
    -x "test/*" \
    -x "tests/*" \
    -q

# Verify the zip was created
if [ ! -f "$OUTPUT_FILE" ]; then
    echo -e "${RED}❌ Failed to create package${NC}"
    exit 1
fi

# Get file size
SIZE=$(du -h "$OUTPUT_FILE" | cut -f1)

# List contents for verification
echo ""
echo "Package contents:"
echo "----------------"
unzip -l "$OUTPUT_FILE" | tail -n +4 | sed '$d' | sed '$d'

echo ""
echo -e "${GREEN}✅ Package created successfully!${NC}"
echo -e "📦 Output: ${YELLOW}$OUTPUT_FILE${NC}"
echo -e "📏 Size: ${YELLOW}$SIZE${NC}"
echo -e "🔖 Version: ${YELLOW}$VERSION${NC}"

echo ""
echo "Next steps:"
echo "-----------"
echo "1. Test the extension:"
echo "   - Open Chrome Extensions (chrome://extensions)"
echo "   - Enable Developer mode"
echo "   - Drag and drop $OUTPUT_FILE"
echo ""
echo "2. Upload to Chrome Web Store:"
echo "   - Go to https://chrome.google.com/webstore/devconsole"
echo "   - Click 'New Item'"
echo "   - Upload $OUTPUT_FILE"
echo "   - Fill in store listing details"
echo "   - Upload screenshots from store/ directory"
echo "   - Set visibility to 'Unlisted'"
echo "   - Submit for review"
echo ""
echo "3. Create screenshots (if not done):"
echo "   - See store/SCREENSHOTS.md for specifications"
echo ""

# Optional: Validate manifest
echo "Validating manifest.json..."
if command -v jq &> /dev/null; then
    if jq empty "$EXTENSION_DIR/manifest.json" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} manifest.json is valid JSON"
    else
        echo -e "${YELLOW}⚠${NC} manifest.json may have JSON errors"
    fi
else
    echo -e "${YELLOW}ℹ${NC} Install jq to validate manifest JSON"
fi

echo ""
echo -e "${GREEN}🎉 Packaging complete!${NC}"
