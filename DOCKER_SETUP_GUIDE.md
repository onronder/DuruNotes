# Docker Setup Guide for Duru Notes

This guide explains how to set up and run the Duru Notes application using Docker for local development.

## Prerequisites

- Docker Desktop installed and running
- Docker Compose (usually comes with Docker Desktop)
- Git
- Flutter SDK (for mobile development)

## Architecture Overview

The Docker setup includes the following services:

### Core Supabase Services
- **PostgreSQL Database** (port 54322): Main database
- **Supabase Studio** (port 54323): Database management UI
- **Kong API Gateway** (port 54321): Main API endpoint
- **GoTrue Auth** (port 54324): Authentication service
- **Realtime** (port 54325): WebSocket connections for real-time features
- **Storage API** (port 54326): File storage service
- **PostgREST** (port 54327): RESTful API for PostgreSQL
- **Postgres Meta** (port 54328): Database introspection API
- **Edge Functions** (port 54329): Serverless functions runtime
- **Imgproxy**: Image transformation service

### Optional Services
- **Flutter Web** (port 8080): Web version of the app (use `--profile web` to enable)

## Quick Start

### 1. Clone and Setup

```bash
# Clone the repository
git clone <your-repo-url>
cd duru-notes

# Copy the environment template
cp docker.env.example .env

# Edit .env with your configuration
# IMPORTANT: Generate new JWT secrets for production!
```

### 2. Generate Secure Keys (for production)

```bash
# Generate a new JWT secret (minimum 32 characters)
openssl rand -base64 32

# Generate new API keys using the JWT secret
# You can use: https://supabase.com/docs/guides/self-hosting#generate-api-keys
```

### 3. Start the Services

```bash
# Start all core Supabase services
docker-compose up -d

# Or start with Flutter web app
docker-compose --profile web up -d

# Check service status
docker-compose ps

# View logs
docker-compose logs -f [service-name]
```

### 4. Access the Services

- **Supabase Studio**: http://localhost:54323
- **API Gateway**: http://localhost:54321
- **Flutter Web** (if enabled): http://localhost:8080

### 5. Initialize the Database

The database migrations in `supabase/migrations/` will be automatically applied when the database starts.

## Development Workflow

### Running the Flutter App

#### For Web (using Docker)
```bash
# Build and run the web version
docker-compose --profile web up -d flutter-web
```

#### For Mobile (iOS/Android)
```bash
# Update your Flutter app configuration to point to local Supabase
# In your Flutter code, use:
# SUPABASE_URL: http://localhost:54321
# SUPABASE_ANON_KEY: (from your .env file)

# Run the Flutter app
flutter run
```

### Working with Edge Functions

1. Place your functions in `supabase/functions/`
2. The functions will be automatically loaded by the Edge Runtime
3. Access functions at: `http://localhost:54329/functions/v1/<function-name>`

### Database Management

```bash
# Access PostgreSQL directly
docker exec -it duru-notes-db psql -U postgres

# Create a database backup
docker exec duru-notes-db pg_dump -U postgres postgres > backup.sql

# Restore from backup
docker exec -i duru-notes-db psql -U postgres postgres < backup.sql
```

## Common Commands

```bash
# Stop all services
docker-compose down

# Stop and remove volumes (WARNING: Deletes all data!)
docker-compose down -v

# Rebuild services
docker-compose build

# View service logs
docker-compose logs -f [service-name]

# Execute commands in a container
docker exec -it [container-name] [command]

# Clean up Docker resources
docker system prune -a
```

## Troubleshooting

### Port Conflicts
If you get port conflict errors, either:
1. Stop conflicting services
2. Or modify the port mappings in `docker-compose.yml`

### Database Connection Issues
```bash
# Check if database is healthy
docker-compose ps
docker exec duru-notes-db pg_isready -U postgres

# Reset the database
docker-compose down -v
docker-compose up -d
```

### Edge Functions Not Loading
```bash
# Check function logs
docker-compose logs -f supabase-edge-functions

# Verify function files exist
ls -la supabase/functions/
```

### Storage Issues
```bash
# Check storage permissions
docker exec duru-notes-storage ls -la /var/lib/storage

# Clear storage cache
docker-compose restart supabase-storage supabase-imgproxy
```

## Environment Variables

Key environment variables (see `docker.env.example` for full list):

- `POSTGRES_PASSWORD`: Database password
- `JWT_SECRET`: Secret for JWT tokens (min 32 chars)
- `ANON_KEY`: Public API key
- `SERVICE_ROLE_KEY`: Service role key (admin access)
- `SMTP_*`: Email configuration
- `FCM_*`: Firebase Cloud Messaging for push notifications
- `SENTRY_*`: Error tracking configuration
- `ADAPTY_*`: In-app purchase configuration

## Security Considerations

⚠️ **For Production:**
1. Generate new JWT secrets and API keys
2. Use strong passwords
3. Configure proper SMTP settings
4. Set up SSL/TLS certificates
5. Restrict database access
6. Enable authentication requirements
7. Configure proper CORS settings

## Additional Resources

- [Supabase Self-Hosting Guide](https://supabase.com/docs/guides/self-hosting)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Flutter Documentation](https://flutter.dev/docs)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)

## Support

For issues specific to this Docker setup:
1. Check the logs: `docker-compose logs -f`
2. Verify all services are running: `docker-compose ps`
3. Ensure ports are not in use: `lsof -i :54321` (on macOS/Linux)
4. Check Docker Desktop resources (memory/CPU allocation)

## Notes

- The `volumes/` directory will be created automatically to persist data
- Database data is stored in `volumes/db/data/`
- Storage files are saved in `volumes/storage/`
- All services are configured to restart automatically unless stopped
