# Makefile for Duru Notes Docker Environment
# Usage: make [command]

.PHONY: help up down restart logs status clean reset shell-db backup restore build web

# Default target
help:
	@echo "Duru Notes Docker Commands"
	@echo "=========================="
	@echo ""
	@echo "Available commands:"
	@echo "  make up        - Start all core Supabase services"
	@echo "  make web       - Start all services including Flutter web"
	@echo "  make down      - Stop all services"
	@echo "  make restart   - Restart all services"
	@echo "  make logs      - View logs (all services)"
	@echo "  make status    - Check service status"
	@echo "  make clean     - Stop services and remove volumes (WARNING: Deletes data!)"
	@echo "  make reset     - Complete reset including volumes and images"
	@echo "  make shell-db  - Access PostgreSQL shell"
	@echo "  make backup    - Backup database to backup.sql"
	@echo "  make restore   - Restore database from backup.sql"
	@echo "  make build     - Rebuild all services"
	@echo ""
	@echo "Service-specific logs:"
	@echo "  make logs-db       - Database logs"
	@echo "  make logs-auth     - Authentication service logs"
	@echo "  make logs-storage  - Storage service logs"
	@echo "  make logs-functions - Edge functions logs"
	@echo ""

# Start services
up:
	@echo "🚀 Starting Supabase services..."
	@docker-compose up -d
	@echo "✅ Services started. Access Supabase Studio at http://localhost:54323"

# Start with web
web:
	@echo "🚀 Starting all services including Flutter web..."
	@docker-compose --profile web up -d
	@echo "✅ Services started. Access Flutter web at http://localhost:8080"

# Stop services
down:
	@echo "🛑 Stopping all services..."
	@docker-compose down
	@echo "✅ Services stopped"

# Restart services
restart: down up

# View logs
logs:
	@docker-compose logs -f

# Service-specific logs
logs-db:
	@docker-compose logs -f supabase-db

logs-auth:
	@docker-compose logs -f supabase-auth

logs-storage:
	@docker-compose logs -f supabase-storage

logs-functions:
	@docker-compose logs -f supabase-edge-functions

# Check status
status:
	@echo "📊 Service Status:"
	@docker-compose ps

# Clean everything (WARNING: Deletes data)
clean:
	@echo "⚠️  WARNING: This will delete all data!"
	@read -p "Are you sure? (y/N): " confirm && [ "$$confirm" = "y" ] || exit 1
	@docker-compose down -v
	@rm -rf volumes/
	@echo "✅ All data removed"

# Complete reset
reset: clean
	@docker-compose down --rmi all
	@echo "✅ Complete reset done"

# Database shell
shell-db:
	@docker exec -it duru-notes-db psql -U postgres

# Backup database
backup:
	@echo "💾 Creating database backup..."
	@docker exec duru-notes-db pg_dump -U postgres postgres > backup.sql
	@echo "✅ Backup saved to backup.sql"

# Restore database
restore:
	@if [ ! -f backup.sql ]; then echo "❌ backup.sql not found"; exit 1; fi
	@echo "📥 Restoring database from backup.sql..."
	@docker exec -i duru-notes-db psql -U postgres postgres < backup.sql
	@echo "✅ Database restored"

# Build services
build:
	@echo "🔨 Building services..."
	@docker-compose build
	@echo "✅ Build complete"

# Initialize environment
init:
	@if [ ! -f .env ]; then \
		echo "📝 Creating .env from template..."; \
		cp docker.env.example .env; \
		echo "✅ .env created. Please edit it with your configuration."; \
	else \
		echo "✅ .env already exists"; \
	fi
	@mkdir -p volumes/db/data volumes/storage volumes/api
	@echo "✅ Directories created"

# Quick setup (init + up)
setup: init
	@echo "⚠️  Please ensure you've configured .env file"
	@read -p "Continue? (y/N): " confirm && [ "$$confirm" = "y" ] || exit 1
	@make up

# Health check
health:
	@echo "🏥 Checking service health..."
	@docker exec duru-notes-db pg_isready -U postgres && echo "✅ Database: Healthy" || echo "❌ Database: Unhealthy"
	@curl -s http://localhost:54321/auth/v1/health > /dev/null && echo "✅ Auth: Healthy" || echo "❌ Auth: Unhealthy"
	@curl -s http://localhost:54321/rest/v1/ > /dev/null && echo "✅ REST API: Healthy" || echo "❌ REST API: Unhealthy"
	@curl -s http://localhost:54323 > /dev/null && echo "✅ Studio: Healthy" || echo "❌ Studio: Unhealthy"
