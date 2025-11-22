# API Service

Node.js REST API with Express, following layered architecture and best practices.

## Table of Contents

- [Endpoints](#-endpoints)
- [Project Structure](#-project-structure)
- [Request Flow](#-request-flow)
- [Running Locally](#-running-locally)
- [Testing](#-testing-endpoints)

---

## Endpoints

### Health Checks

| Method | Endpoint  | Description                           | Response          |
|--------|-----------|---------------------------------------|-------------------|
| GET    | `/status` | Simple status check                   | `{"status":"OK"}` |
| GET    | `/ready`  | Readiness probe (tests DB connection) | `{"ready":true}`  |

### Items

| Method | Endpoint      | Description       | Response                |
|--------|---------------|-------------------|-------------------------|
| GET    | `/items`      | Get all items     | `[{item}, {item}, ...]` |
| GET    | `/items/:id`  | Get item by ID    | `{item}`                |

**Item Schema:**
```json
{
  "id": 1,
  "title": "Item 1",
  "body": "Content of item 1",
  "createdAt": "2025-11-22T13:10:01.806Z"
}
```

---

## Project Structure

```
api/
├── src/
│   ├── config/                 # Configuration
│   │   ├── app.js             # App settings (port, CORS, logging)
│   │   └── database.js        # Database connection pool
│   │
│   ├── routes/                 # Route definitions
│   │   ├── health.routes.js   # Health check routes
│   │   └── item.routes.js     # Item routes
│   │
│   ├── controllers/            # HTTP handlers
│   │   ├── health.controller.js
│   │   └── item.controller.js
│   │
│   ├── services/               # Business logic
│   │   └── item.service.js
│   │
│   ├── repositories/           # Data access layer
│   │   └── item.repository.js
│   │
│   ├── models/                 # Data models
│   │   └── item.model.js
│   │
│   ├── middlewares/            # Express middlewares
│   │   ├── error.middleware.js
│   │   └── logger.middleware.js
│   │
│   ├── utils/                  # Utilities
│   │   ├── errors.js          # Custom error classes
│   │   └── logger.js          # Structured logger
│   │
│   └── app.js                  # Entry point
│
├── Dockerfile
├── package.json
├── .env.exemple               # Environment variables template
└── README.md                  # This file
```

---

## Request Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                         CLIENT REQUEST                          │
│                      GET /items/:id                             │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│ 1. MIDDLEWARE LAYER                                             │
│    ├── logger.middleware.js    (logs request)                   │
│    └── Routes matching                                          │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│ 2. ROUTES LAYER                                                 │
│    └── item.routes.js                                           │
│        Maps GET /items/:id → ItemController.getById()           │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│ 3. CONTROLLER LAYER                                             │
│    └── item.controller.js                                       │
│        ├── Extracts ID from request                             │
│        ├── Validates ID (returns 400 if invalid)                │
│        ├── Calls ItemService.getById(id)                        │
│        └── Formats response                                     │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│ 4. SERVICE LAYER                                                │
│    └── item.service.js                                          │
│        ├── Contains business logic                              │
│        ├── Calls ItemRepository.findById(id)                    │
│        └── Throws NotFoundError if not found                    │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│ 5. REPOSITORY LAYER                                             │
│    └── item.repository.js                                       │
│        ├── Executes SQL query: SELECT * FROM items WHERE id=$1  │
│        └── Returns raw database row                             │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│ 6. MODEL LAYER                                                  │
│    └── item.model.js                                            │
│        └── Transforms data (created_at → createdAt)             │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│ 7. RESPONSE                                                     │
│    ├── Success: 200 + JSON                                      │
│    └── Error: Caught by error.middleware.js                     │
└─────────────────────────────────────────────────────────────────┘
```

## Running Locally

### With Docker (recommended)
```bash
# From project root
docker compose up -d --build
```

### Without Docker
```bash
# 1. Create .env file
cp .env.exemple .env

# 2. Modify DB_HOST to localhost (instead of 'db')
# DB_HOST=localhost

# 3. Install dependencies
npm install

# 4. Start the API
npm start
```

**API will be available at:** `http://localhost:3000`


## Testing Endpoints

```bash
# Health check
curl http://localhost:3000/status

# Readiness probe
curl http://localhost:3000/ready

# Get all items
curl http://localhost:3000/items

# Get item by ID
curl http://localhost:3000/items/1
```

---

**Built with:** Node.js 22 • Express 4.18 • PostgreSQL 15 • Docker
