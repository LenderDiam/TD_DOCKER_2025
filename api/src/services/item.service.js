const Item = require('../models/item.model');
const ItemRepository = require('../repositories/item.repository');
const { NotFoundError } = require('../utils/errors');

class ItemService {
  constructor(itemRepository = new ItemRepository()) {
    this.itemRepository = itemRepository;
  }

  /**
   * Get all items
   * @returns {Promise<Item[]>}
   */
  async getAllItems() {
    const rows = await this.itemRepository.findAll();
    return Item.fromDatabaseArray(rows);
  }

  /**
   * Get item by ID
   * @param {number} id - Item ID
   * @returns {Promise<Item>}
   * @throws {NotFoundError} If item not found
   */
  async getItemById(id) {
    const row = await this.itemRepository.findById(id);
    if (!row) {
      throw new NotFoundError('Item');
    }
    return Item.fromDatabase(row);
  }

  /**
   * Check if database is healthy
   * @returns {Promise<Object>}
   */
  async checkDatabaseHealth() {
    const isHealthy = await this.itemRepository.healthCheck();
    return {
      database: isHealthy ? 'healthy' : 'unhealthy',
      timestamp: new Date().toISOString()
    };
  }
}

module.exports = ItemService;
