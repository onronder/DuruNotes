#!/bin/bash

# Replace print() with debugPrint() in production code
echo "Replacing print() with debugPrint()..."

# Find all Dart files and replace print( with debugPrint(
find lib/ -name "*.dart" -type f | while read file; do
    # Check if file contains print( but not debugPrint
    if grep -q "print(" "$file" && ! grep -q "debugPrint" "$file"; then
        # Add import if not present
        if ! grep -q "import 'package:flutter/foundation.dart';" "$file"; then
            # Add import after the first import or at the beginning
            if grep -q "^import " "$file"; then
                # Add after last import
                sed -i '' "/^import /a\\
import 'package:flutter/foundation.dart';
" "$file"
            else
                # Add at the beginning
                sed -i '' "1i\\
import 'package:flutter/foundation.dart';\\
" "$file"
            fi
        fi
    fi
    
    # Replace print( with debugPrint(
    if grep -q "[^debug]print(" "$file"; then
        echo "Fixing: $file"
        # Replace print( with debugPrint( when not preceded by 'debug'
        sed -i '' 's/\([^a-zA-Z]\)print(/\1debugPrint(/g' "$file"
        # Handle print( at the beginning of a line
        sed -i '' 's/^print(/debugPrint(/g' "$file"
    fi
done

echo "Done! Replaced all print() with debugPrint()."
