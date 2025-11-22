const { Pool } = require('pg');
const logger = require('../utils/logger');

/**
 * Validates that required environment variables are set
 * @param {string} key - Environment variable name
 * @param {string} [defaultValue] - Optional default value
 * @returns {string} The environment variable value or default
 * @throws {Error} If the variable is not set and no default provided
 */
const getEnv = (key, defaultValue = null) => {
  const value = process.env[key];
  if (!value && defaultValue === null) {
    throw new Error(`Missing required environment variable: ${key}`);
  }
  return value || defaultValue;
};

/**
 * Parse integer environment variable with default
 * @param {string} key - Environment variable name
 * @param {number} defaultValue - Default value
 * @returns {number}
 */
const getEnvInt = (key, defaultValue) => {
  const value = process.env[key];
  return value ? parseInt(value, 10) : defaultValue;
};

/**
 * Database configuration object
 */
const dbConfig = {
  // Connection settings
  host: getEnv('DB_HOST', 'localhost'),
  port: getEnvInt('DB_PORT', 5432),
  user: getEnv('DB_USER'),
  password: getEnv('DB_PASSWORD'),
  database: getEnv('DB_NAME'),
  
  // Pool settings (externalized with defaults)
  max: getEnvInt('DB_POOL_MAX', 10),
  idleTimeoutMillis: getEnvInt('DB_POOL_IDLE_TIMEOUT', 30000),
  connectionTimeoutMillis: getEnvInt('DB_POOL_CONNECTION_TIMEOUT', 2000),
};

// Log configuration (without sensitive data)
logger.info('Database configuration loaded', {
  host: dbConfig.host,
  port: dbConfig.port,
  database: dbConfig.database,
  user: dbConfig.user,
  poolMax: dbConfig.max
});

const pool = new Pool(dbConfig);

// Handle pool errors
pool.on('error', (err) => {
  logger.error('Unexpected database pool error', { error: err.message });
});

// Test connection on startup
pool.query('SELECT NOW()', (err) => {
  if (err) {
    logger.error('Failed to connect to database', { error: err.message });
  } else {
    logger.info('Database connection established successfully');
  }
});

module.exports = pool;
