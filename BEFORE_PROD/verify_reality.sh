#!/bin/bash

# Reality Check Script - Run this to see the truth about the project
# Created: December 2024
# Purpose: Verify actual vs claimed project status

echo "============================================"
echo "   🎭 DURU NOTES REALITY CHECK"
echo "============================================"
echo ""

# Check if domain architecture is enabled
echo "1️⃣  Domain Architecture Status:"
echo -n "   "
grep "const bool useRefactoredArchitecture" lib/providers.dart | head -1
echo ""

# Count build errors
echo "2️⃣  Build Errors with Domain Enabled:"
echo -n "   Error Count: "
flutter analyze 2>/dev/null | grep -c "error" || echo "Run 'flutter analyze' manually"
echo ""

# Check UI model usage
echo "3️⃣  UI Model Usage:"
echo -n "   LocalNote references (OLD): "
grep -r "LocalNote" lib/ui/ 2>/dev/null | wc -l | tr -d ' '
echo -n "   domain.Note references (NEW): "
grep -r "domain\.Note" lib/ui/ 2>/dev/null | wc -l | tr -d ' '
echo ""

# Check for memory leaks
echo "4️⃣  Memory Leak Issues:"
echo -n "   Undisposed controllers: "
grep -r "TextEditingController" lib/ 2>/dev/null | grep -v "dispose" | wc -l | tr -d ' '
echo ""

# Check conditional providers
echo "5️⃣  Dual Architecture Conditionals:"
echo -n "   Conditional providers: "
grep "useRefactoredArchitecture" lib/providers.dart 2>/dev/null | wc -l | tr -d ' '
echo ""

# Check property mismatches
echo "6️⃣  Property Name Conflicts:"
echo -n "   'body' in domain: "
grep "final String body" lib/domain/entities/*.dart 2>/dev/null | wc -l | tr -d ' '
echo -n "   'content' in database: "
grep "String content" lib/data/local/app_db.dart 2>/dev/null | wc -l | tr -d ' '
echo ""

# Summary
echo "============================================"
echo "   📊 SUMMARY"
echo "============================================"

if grep -q "useRefactoredArchitecture = false" lib/providers.dart 2>/dev/null; then
    echo "   ❌ Domain architecture: DISABLED"
else
    echo "   ✅ Domain architecture: Enabled"
fi

LOCAL_REFS=$(grep -r "LocalNote" lib/ui/ 2>/dev/null | wc -l | tr -d ' ')
DOMAIN_REFS=$(grep -r "domain\.Note" lib/ui/ 2>/dev/null | wc -l | tr -d ' ')

if [ "$LOCAL_REFS" -gt "$DOMAIN_REFS" ]; then
    echo "   ❌ UI Migration: Using OLD models ($LOCAL_REFS old vs $DOMAIN_REFS new)"
else
    echo "   ✅ UI Migration: Using domain models"
fi

echo ""
echo "============================================"
echo "   📁 Key Files to Check:"
echo "============================================"
echo "   • lib/providers.dart (line 114)"
echo "   • lib/domain/entities/note.dart"
echo "   • lib/infrastructure/mappers/"
echo "   • lib/ui/notes_list_screen.dart"
echo ""
echo "For detailed fixes, see:"
echo "   BEFORE_PROD/CRITICAL_GAPS/*.md"
echo "============================================"