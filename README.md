# TD_DOCKER_2025

Complete containerized application: Node.js API + Vue.js Frontend + PostgreSQL Database

## Quick Start

```powershell
# Clone and configure
git clone https://github.com/LenderDiam/TD_DOCKER_2025.git
cd TD_DOCKER_2025
cp .env.exemple .env

# Launch the complete stack
docker compose up -d
```
Frontend: http://localhost:8080
API: http://localhost:3000

## Architecture

```
Frontend (Vue + Nginx:8080) → API (Node.js:3000) → DB (PostgreSQL:5432)
```

The stack deploys automatically with Docker Compose:
- Frontend serves static files and proxies requests to the API
- API exposes `/status` and `/items` endpoints
- PostgreSQL automatically initializes the database with test data

## Useful Commands

```powershell
# View logs
docker compose logs -f

# Stop the stack
docker compose down

# Rebuild after changes
docker compose up -d --build

# Test the API
curl http://localhost:3000/status
```

## Automation Scripts

```powershell
# Automatic build, scan and deployment
.\build-and-deploy.ps1

# Run all tests
.\run-all-tests.ps1
```

## Docker Commands

```powershell
# Start services
docker compose up -d

# Stop services
docker compose down

# View logs
docker compose logs -f

# Rebuild images
docker compose build --no-cache

# View resources usage
docker compose ps
```

## Environment Variables

Main variables (see `.env.exemple`):

```env
# Database
POSTGRES_USER=docker_user
POSTGRES_PASSWORD=secure_password
POSTGRES_DB=td_docker_db

# API
API_PORT=3000
NODE_ENV=production
```

## Troubleshooting

### Build Issues with Docker Hub Images

If you encounter problems pulling images from Docker Hub, you can build locally instead:

1. Open `docker-compose.yml`
2. Comment the `image:` lines
3. Uncomment the `build:` sections with local context

```yaml
# Use this for Docker Hub images (default)
image: lenderdiam/td-docker-api:latest

# Use this for local builds (if Docker Hub unavailable)
# build:
#   context: ./api
#   dockerfile: Dockerfile
```

Then rebuild: `docker compose up -d --build`
 
## Complete Documentation

**[RAPPORT.md](RAPPORT.md)** - Detailed project report.
