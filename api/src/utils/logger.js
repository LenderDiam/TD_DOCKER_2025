const LOG_LEVELS = {
  ERROR: 0,
  WARN: 1,
  INFO: 2,
  DEBUG: 3
};

const LOG_LEVEL_NAMES = {
  0: 'ERROR',
  1: 'WARN',
  2: 'INFO',
  3: 'DEBUG'
};

class Logger {
  constructor() {
    // Get log level from environment (default: INFO)
    const levelName = (process.env.LOG_LEVEL || 'info').toUpperCase();
    this.level = LOG_LEVELS[levelName] !== undefined ? LOG_LEVELS[levelName] : LOG_LEVELS.INFO;
    
    // Pretty print in development
    this.pretty = process.env.LOG_PRETTY === 'true' || process.env.NODE_ENV === 'development';
  }

  _formatMessage(level, message, meta = {}) {
    const timestamp = new Date().toISOString();
    const levelName = LOG_LEVEL_NAMES[level];
    
    if (this.pretty) {
      // Human-readable format for development
      const metaString = Object.keys(meta).length > 0 ? `\n  ${JSON.stringify(meta, null, 2)}` : '';
      return `[${timestamp}] [${levelName}] ${message}${metaString}`;
    } else {
      // JSON format for production
      return JSON.stringify({
        timestamp,
        level: levelName,
        message,
        ...meta
      });
    }
  }

  _shouldLog(level) {
    return level <= this.level;
  }

  error(message, meta = {}) {
    if (this._shouldLog(LOG_LEVELS.ERROR)) {
      console.error(this._formatMessage(LOG_LEVELS.ERROR, message, meta));
    }
  }

  warn(message, meta = {}) {
    if (this._shouldLog(LOG_LEVELS.WARN)) {
      console.warn(this._formatMessage(LOG_LEVELS.WARN, message, meta));
    }
  }

  info(message, meta = {}) {
    if (this._shouldLog(LOG_LEVELS.INFO)) {
      console.log(this._formatMessage(LOG_LEVELS.INFO, message, meta));
    }
  }

  debug(message, meta = {}) {
    if (this._shouldLog(LOG_LEVELS.DEBUG)) {
      console.log(this._formatMessage(LOG_LEVELS.DEBUG, message, meta));
    }
  }
}

module.exports = new Logger();
