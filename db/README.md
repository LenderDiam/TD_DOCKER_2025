# Database Service

PostgreSQL 15 database with automatic initialization.

## Table of Contents

- [Schema](#schema)
- [Project Structure](#project-structure)
- [Initialization](#initialization)
- [Running Locally](#running-locally)
- [Common Operations](#common-operations)

---

## Schema

### Table: `items`

| Column       | Type                        | Constraints   | Description           |
|--------------|-----------------------------|---------------|-----------------------|
| `id`         | `SERIAL`                    | PRIMARY KEY   | Auto-incremented ID   |
| `title`      | `VARCHAR(255)`              | NOT NULL      | Item title            |
| `body`       | `TEXT`                      | -             | Item content          |
| `created_at` | `TIMESTAMP WITH TIME ZONE`  | DEFAULT now() | Creation timestamp    |

**Indexes:**
- Primary key on `id` (automatic)

**Sample Data:**
```sql
| id | title   | body                | created_at                |
|----|---------|---------------------|---------------------------|
| 1  | Item 1  | Content of item 1   | 2025-11-22T13:10:01.806Z  |
| 2  | Item 2  | Content of item 2   | 2025-11-22T13:10:01.806Z  |
| 3  | Item 3  | Content of item 3   | 2025-11-22T13:10:01.806Z  |
```

---

## Project Structure

```
db/
├── init/
│   └── 001_init_db.sql     # Database initialization script
├── .env.exemple            # Environment variables template
└── README.md               # This file
```

### Initialization Script

The `001_init_db.sql` script creates:
1. Database user (`td_user`)
2. Database (`td_db`)
3. Table (`items`)
4. Sample data (3 items)

**Note:** Scripts are idempotent and safe to re-run.

---

## Initialization

### Automatic (Docker)

Scripts in `init/` are executed **once** on first container startup (when volume is empty).

```bash
# First start (runs init scripts)
docker compose up -d db

# Check initialization logs
docker compose logs db
```

### Manual Reset

```bash
# Remove volume and restart (re-runs init scripts)
docker compose down -v
docker compose up -d db
```

---

## Running Locally

### With Docker (recommended)

```bash
# From project root
docker compose up -d db

# Check status
docker compose ps db

# View logs
docker compose logs db -f
```

### Health Check

```bash
# Check if database is ready
docker compose exec db pg_isready -U td_user -d td_db

# Expected output: "accepting connections"
```


---

## Common Operations

### Connect to Database

```bash
# Using psql
docker compose exec db psql -U td_user -d td_db

# From host (if psql installed)
psql -h localhost -p 5432 -U td_user -d td_db
```

### View Tables and Data

```sql
-- List tables
\dt

-- Describe items table
\d items

-- View all items
SELECT * FROM items;
```

### Backup Database

```bash
# SQL format
docker compose exec db pg_dump -U td_user td_db > backup.sql

# Custom format (compressed)
docker compose exec db pg_dump -U td_user -Fc td_db > backup.dump
```

### Restore Database

```bash
# From SQL file
docker compose exec -T db psql -U td_user -d td_db < backup.sql

# From custom format
docker compose exec db pg_restore -U td_user -d td_db backup.dump
```
