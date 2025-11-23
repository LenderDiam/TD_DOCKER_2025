-- =============================================================================
-- Database Initialization Script
-- =============================================================================
-- Purpose: Initialize the TD_DOCKER_2025 database with required tables and
--          sample data. This script is idempotent and safe to re-run.
--
-- Execution: Automatically executed by PostgreSQL container on first startup
--            (when data volume is empty)
--
-- Note: All operations use idempotent patterns (IF NOT EXISTS, ON CONFLICT)
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Step 1: Create Database User
-- -----------------------------------------------------------------------------
-- Creates 'td_user' if it doesn't already exist
DO
$$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_user WHERE usename = 'td_user') THEN
    CREATE USER td_user WITH PASSWORD 'td_password';
    RAISE NOTICE 'User td_user created successfully';
  ELSE
    RAISE NOTICE 'User td_user already exists, skipping';
  END IF;
END
$$;

-- -----------------------------------------------------------------------------
-- Step 2: Create Database
-- -----------------------------------------------------------------------------
-- Creates 'td_db' database if it doesn't exist
SELECT 'CREATE DATABASE td_db'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'td_db')\gexec

-- Grant all privileges on the database to td_user
GRANT ALL PRIVILEGES ON DATABASE td_db TO td_user;

-- Connect to the newly created database
\c td_db;

-- -----------------------------------------------------------------------------
-- Step 3: Create Schema - Items Table
-- -----------------------------------------------------------------------------
-- Table: items
-- Description: Stores application items with title, body, and creation date
CREATE TABLE IF NOT EXISTS items (
    id SERIAL PRIMARY KEY,                          -- Auto-increment ID
    title VARCHAR(255) NOT NULL,                    -- Item title (required)
    body TEXT,                                      -- Item content (optional)
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now() -- Creation timestamp
);

-- Add table comment for documentation
COMMENT ON TABLE items IS 'Application items storage';
COMMENT ON COLUMN items.id IS 'Unique identifier for each item';
COMMENT ON COLUMN items.title IS 'Item title (max 255 characters)';
COMMENT ON COLUMN items.body IS 'Item content or description';
COMMENT ON COLUMN items.created_at IS 'Timestamp when item was created';

-- -----------------------------------------------------------------------------
-- Step 4: Insert Sample Data
-- -----------------------------------------------------------------------------
-- Inserts 3 sample items for testing and demonstration
-- Uses ON CONFLICT to prevent duplicate inserts on re-runs
INSERT INTO items (title, body) VALUES
    ('Item 1', 'Content of item 1'),
    ('Item 2', 'Content of item 2'),
    ('Item 3', 'Content of item 3')
ON CONFLICT DO NOTHING;

-- -----------------------------------------------------------------------------
-- Initialization Complete
-- -----------------------------------------------------------------------------
-- Database: td_db
-- Tables: items (3 sample rows)
-- User: td_user (with full privileges)
-- =============================================================================