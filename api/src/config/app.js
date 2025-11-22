/**
 * Get environment variable with default value
 * @param {string} key - Environment variable name
 * @param {string|number} defaultValue - Default value
 * @returns {string}
 */
const getEnv = (key, defaultValue) => {
  return process.env[key] || defaultValue;
};

/**
 * Parse integer environment variable
 * @param {string} key - Environment variable name
 * @param {number} defaultValue - Default value
 * @returns {number}
 */
const getEnvInt = (key, defaultValue) => {
  const value = process.env[key];
  return value ? parseInt(value, 10) : defaultValue;
};

/**
 * Parse boolean environment variable
 * @param {string} key - Environment variable name
 * @param {boolean} defaultValue - Default value
 * @returns {boolean}
 */
const getEnvBool = (key, defaultValue) => {
  const value = process.env[key];
  if (!value) return defaultValue;
  return value.toLowerCase() === 'true' || value === '1';
};

/**
 * Application configuration object
 */
const config = {
  // Server settings
  port: getEnvInt('PORT', 3000),
  nodeEnv: getEnv('NODE_ENV', 'development'),
  
  // CORS settings
  cors: {
    origin: getEnv('CORS_ORIGIN', '*'),
    credentials: getEnvBool('CORS_CREDENTIALS', true)
  },
  
  // Logging settings
  logging: {
    level: getEnv('LOG_LEVEL', 'info'),
    pretty: getEnvBool('LOG_PRETTY', true)
  }
};

module.exports = config;
