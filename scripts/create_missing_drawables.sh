#!/bin/bash

# Create missing Android drawable resources
DRAWABLE_DIR="android/app/src/main/res/drawable"

# Function to create a simple vector drawable
create_drawable() {
    local filename=$1
    local icon_type=$2

    cat > "$DRAWABLE_DIR/$filename.xml" << EOF
<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="24dp"
    android:height="24dp"
    android:viewportWidth="24"
    android:viewportHeight="24">
    <path
        android:fillColor="?android:attr/colorControlNormal"
        android:pathData="M12,2C6.48,2 2,6.48 2,12s4.48,10 10,10 10,-4.48 10,-10S17.52,2 12,2zM13,17h-2v-6h2v6zM13,9h-2L11,7h2v2z" />
</vector>
EOF
}

# Create missing drawables
create_drawable "ic_settings" "settings"
create_drawable "ic_camera" "camera"
create_drawable "ic_meeting" "meeting"
create_drawable "ic_lightbulb" "lightbulb"
create_drawable "ic_task" "task"
create_drawable "ic_empty_notes" "empty"
create_drawable "ic_mic" "mic"
create_drawable "ic_voice" "voice"
create_drawable "ic_pin" "pin"
create_drawable "ic_refresh" "refresh"

echo "Created missing drawable resources"