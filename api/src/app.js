require('dotenv').config();
const express = require('express');
const cors = require('cors');

const appConfig = require('./config/app');
const logger = require('./utils/logger');
const requestLogger = require('./middlewares/logger.middleware');
const { errorHandler, notFoundHandler } = require('./middlewares/error.middleware');
const itemRoutes = require('./routes/item.routes');
const healthRoutes = require('./routes/health.routes');

const app = express();

app.use(cors(appConfig.cors));

app.use(express.json());
app.use(express.urlencoded({ extended: true }));

app.use(requestLogger);

app.use('/items', itemRoutes);
app.use('/', healthRoutes);

app.use(notFoundHandler);

app.use(errorHandler);

const server = app.listen(appConfig.port, () => {
  logger.info(`API listening on port ${appConfig.port}`, {
    environment: appConfig.nodeEnv,
    port: appConfig.port,
    logLevel: process.env.LOG_LEVEL,
    logPretty: process.env.LOG_PRETTY
  });
  logger.debug('Configuration loaded', appConfig);
});

process.on('SIGTERM', () => {
  logger.info('SIGTERM signal received: closing HTTP server');
  server.close(() => {
    logger.info('HTTP server closed');
    process.exit(0);
  });
});

module.exports = app;