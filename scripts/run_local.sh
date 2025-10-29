#!/bin/bash

# Local Development Run Script for Duru Notes
# This script runs the app with local environment configuration

set -e  # Exit on error

echo "🚀 Duru Notes Local Development"
echo "================================"

# Check if .env.local exists
if [ ! -f ".env.local" ]; then
    echo "❌ No .env.local file found!"
    echo ""
    echo "Creating .env.local from template..."

    if [ -f "env.example" ]; then
        cp env.example .env.local
        echo "✅ Created .env.local from env.example"
        echo ""
        echo "⚠️  Please edit .env.local and add your keys:"
        echo "   - SUPABASE_URL"
        echo "   - SUPABASE_ANON_KEY"
        echo "   - Other service keys as needed"
        echo ""
        echo "Then run this script again."
        exit 1
    else
        echo "❌ No env.example file found!"
        echo "Please create .env.local manually with your configuration"
        exit 1
    fi
fi

# Load and validate environment
echo "📋 Loading environment from .env.local"
export $(cat .env.local | grep -v '^#' | xargs)

# Check for required variables
if [ -z "$SUPABASE_URL" ] || [ -z "$SUPABASE_ANON_KEY" ]; then
    echo "⚠️  Missing required configuration in .env.local:"
    [ -z "$SUPABASE_URL" ] && echo "   - SUPABASE_URL"
    [ -z "$SUPABASE_ANON_KEY" ] && echo "   - SUPABASE_ANON_KEY"
    echo ""
    echo "Please add these to your .env.local file"
    exit 1
fi

echo "✅ Environment configured"
echo ""

# Select device
echo "📱 Select target device:"
echo "1) iOS Simulator"
echo "2) Android Emulator"
echo "3) Physical Device (USB)"
echo "4) Chrome (Web)"
echo "5) All available devices"

read -p "Enter choice (1-5): " DEVICE_CHOICE

case $DEVICE_CHOICE in
    1)
        echo "📱 Starting iOS Simulator..."
        open -a Simulator
        sleep 3
        flutter run
        ;;
    2)
        echo "📱 Starting Android Emulator..."
        flutter run
        ;;
    3)
        echo "📱 Running on physical device..."
        flutter run
        ;;
    4)
        echo "🌐 Running on Chrome..."
        flutter run -d chrome
        ;;
    5)
        echo "📱 Running on all available devices..."
        flutter run -d all
        ;;
    *)
        echo "❌ Invalid choice"
        exit 1
        ;;
esac