#!/bin/bash

# Fix withOpacity deprecation warning
# Replace .withOpacity(X) with .withValues(opacity: X)

echo "Fixing withOpacity deprecation warnings..."

# Find all Dart files and replace withOpacity
find lib/ test/ -name "*.dart" -type f | while read file; do
    # Check if file contains withOpacity
    if grep -q "withOpacity" "$file"; then
        echo "Fixing: $file"
        # Use sed to replace the pattern
        # This handles the pattern .withOpacity(number)
        sed -i '' 's/\.withOpacity(\([^)]*\))/.withValues(opacity: \1)/g' "$file"
    fi
done

echo "Done! Fixed all withOpacity occurrences."
