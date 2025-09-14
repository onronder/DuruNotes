#!/bin/bash

# Docker Start Script for Duru Notes
# This script helps you quickly set up and run the Docker environment

set -e

echo "🚀 Duru Notes Docker Setup"
echo "=========================="
echo ""

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker Desktop first."
    exit 1
fi

echo "✅ Docker is running"

# Check if .env file exists
if [ ! -f .env ]; then
    if [ -f docker.env.example ]; then
        echo "📝 Creating .env file from template..."
        cp docker.env.example .env
        echo "⚠️  Please edit .env file with your configuration before proceeding."
        echo "   Especially update:"
        echo "   - JWT_SECRET (generate with: openssl rand -base64 32)"
        echo "   - Database passwords"
        echo "   - SMTP settings for email"
        echo ""
        read -p "Press Enter after you've updated .env file..." 
    else
        echo "❌ No .env file found and no template available."
        exit 1
    fi
fi

# Create necessary directories
echo "📁 Creating necessary directories..."
mkdir -p volumes/db/data
mkdir -p volumes/storage
mkdir -p volumes/api

# Check if kong.yml exists
if [ ! -f volumes/api/kong.yml ]; then
    echo "⚠️  Kong configuration not found at volumes/api/kong.yml"
    echo "   Please ensure the Kong configuration file exists."
fi

# Menu
echo ""
echo "What would you like to do?"
echo "1) Start all core services (Supabase)"
echo "2) Start with Flutter web app"
echo "3) Stop all services"
echo "4) View logs"
echo "5) Reset everything (WARNING: Deletes all data!)"
echo "6) Check service status"
echo ""

read -p "Enter your choice (1-6): " choice

case $choice in
    1)
        echo "🔄 Starting core Supabase services..."
        docker-compose up -d
        echo ""
        echo "✅ Services started successfully!"
        echo ""
        echo "📍 Access points:"
        echo "   - Supabase Studio: http://localhost:54323"
        echo "   - API Gateway: http://localhost:54321"
        echo "   - Database: localhost:54322"
        echo ""
        echo "Run 'docker-compose logs -f' to view logs"
        ;;
    2)
        echo "🔄 Starting all services including Flutter web..."
        docker-compose --profile web up -d
        echo ""
        echo "✅ Services started successfully!"
        echo ""
        echo "📍 Access points:"
        echo "   - Flutter Web App: http://localhost:8080"
        echo "   - Supabase Studio: http://localhost:54323"
        echo "   - API Gateway: http://localhost:54321"
        echo ""
        echo "Run 'docker-compose logs -f' to view logs"
        ;;
    3)
        echo "🛑 Stopping all services..."
        docker-compose down
        echo "✅ All services stopped"
        ;;
    4)
        echo "📋 Viewing logs (press Ctrl+C to exit)..."
        docker-compose logs -f
        ;;
    5)
        echo "⚠️  WARNING: This will delete all data including database!"
        read -p "Are you sure? (yes/no): " confirm
        if [ "$confirm" = "yes" ]; then
            echo "🗑️  Removing all services and volumes..."
            docker-compose down -v
            rm -rf volumes/
            echo "✅ Everything has been reset"
        else
            echo "❌ Operation cancelled"
        fi
        ;;
    6)
        echo "📊 Service Status:"
        echo ""
        docker-compose ps
        echo ""
        echo "🔍 Port Usage:"
        echo "   54321 - API Gateway"
        echo "   54322 - PostgreSQL Database"
        echo "   54323 - Supabase Studio"
        echo "   54324 - Auth Service"
        echo "   54325 - Realtime"
        echo "   54326 - Storage API"
        echo "   54327 - PostgREST"
        echo "   54328 - Postgres Meta"
        echo "   54329 - Edge Functions"
        echo "   8080  - Flutter Web (if enabled)"
        ;;
    *)
        echo "❌ Invalid choice"
        exit 1
        ;;
esac

echo ""
echo "Done! 🎉"
