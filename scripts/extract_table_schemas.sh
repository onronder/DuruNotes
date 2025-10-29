#!/bin/bash

# Extract specific table schemas from supabase.md

SUPABASE_MD="supabase/backup/supabase.md"
OUTPUT_DIR="docs/extracted_schemas"

mkdir -p "$OUTPUT_DIR"

# Function to extract table definition
extract_table() {
    local table_name="$1"
    local start_line=$(grep -n "### public\.$table_name$" "$SUPABASE_MD" | cut -d: -f1)

    if [ -z "$start_line" ]; then
        echo "Table $table_name not found"
        return
    fi

    # Find next section (starts with ###)
    local end_line=$(tail -n +$((start_line + 1)) "$SUPABASE_MD" | grep -n "^### " | head -1 | cut -d: -f1)

    if [ -z "$end_line" ]; then
        end_line=100
    fi

    # Extract the section
    sed -n "${start_line},$((start_line + end_line - 1))p" "$SUPABASE_MD" > "$OUTPUT_DIR/${table_name}.md"

    echo "Extracted $table_name ($((end_line)) lines)"
}

# Extract critical tables
extract_table "notes"
extract_table "folders"
extract_table "saved_searches"
extract_table "templates"
extract_table "note_tasks"
extract_table "attachments"
extract_table "note_tags"
extract_table "note_folders"
extract_table "tasks"

echo "All tables extracted to $OUTPUT_DIR"
