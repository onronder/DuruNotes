#!/bin/bash

# Fix withValues incorrect usage
# The correct format should be .withValues(alpha: X) not .withValues(opacity: X)

echo "Fixing withValues usage..."

# Find all Dart files and fix withValues
find lib/ test/ -name "*.dart" -type f | while read file; do
    # Check if file contains withValues(opacity:
    if grep -q "withValues(opacity:" "$file"; then
        echo "Fixing: $file"
        # Replace withValues(opacity: with withValues(alpha:
        sed -i '' 's/withValues(opacity:/withValues(alpha:/g' "$file"
    fi
done

echo "Done! Fixed all withValues usage."
