-- Create user if not exists (idempotent)
DO
$$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_user WHERE usename = 'td_user') THEN
    CREATE USER td_user WITH PASSWORD 'td_password';
  END IF;
END
$$;

-- Create database if not exists
SELECT 'CREATE DATABASE td_db'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'td_db')\gexec

GRANT ALL PRIVILEGES ON DATABASE td_db TO td_user;

\c td_db;

CREATE TABLE IF NOT EXISTS items (
id SERIAL PRIMARY KEY,
title VARCHAR(255) NOT NULL,
body TEXT,
created_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

INSERT INTO items (title, body) VALUES
('Item 1', 'Contenu de l''item 1'),
('Item 2', 'Contenu de l''item 2'),
('Item 3', 'Contenu de l''item 3')
ON CONFLICT DO NOTHING;