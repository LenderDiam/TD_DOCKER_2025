const logger = require('../utils/logger');

/**
 * Logs incoming HTTP requests
 */
const requestLogger = (req, res, next) => {
  const start = Date.now();

  // Log when response is finished
  res.on('finish', () => {
    const duration = Date.now() - start;
    logger.info(`${req.method} ${req.path}`, {
      method: req.method,
      path: req.path,
      statusCode: res.statusCode,
      duration: `${duration}ms`,
      userAgent: req.get('user-agent')
    });
  });

  next();
};

module.exports = requestLogger;
