const ItemService = require('../services/item.service');

class HealthController {
  constructor(itemService = new ItemService()) {
    this.itemService = itemService;
  }

  /**
   * Simple status check
   * @route GET /status
   */
  async status(req, res) {
    res.json({ status: 'OK' });
  }

  /**
   * Readiness check (includes database connection)
   * @route GET /ready
   */
  async ready(req, res, next) {
    try {
      const health = await this.itemService.checkDatabaseHealth();
      const isReady = health.database === 'healthy';
      
      res.status(isReady ? 200 : 503).json({
        ready: isReady,
        ...health
      });
    } catch (error) {
      next(error);
    }
  }
}

module.exports = HealthController;
