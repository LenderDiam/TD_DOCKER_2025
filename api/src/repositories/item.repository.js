const pool = require('../config/database');
const { DatabaseError } = require('../utils/errors');
const logger = require('../utils/logger');

class ItemRepository {
  /**
   * Get all items ordered by id
   * @returns {Promise<Array>} Array of item rows
   * @throws {DatabaseError}
   */
  async findAll() {
    try {
      const query = 'SELECT id, title, body, created_at FROM items ORDER BY id';
      const result = await pool.query(query);
      logger.debug(`Found ${result.rows.length} items`);
      return result.rows;
    } catch (error) {
      logger.error('Failed to fetch items from database', { error: error.message });
      throw new DatabaseError('Failed to retrieve items');
    }
  }

  /**
   * Get item by ID
   * @param {number} id - Item ID
   * @returns {Promise<Object|null>} Item row or null
   * @throws {DatabaseError}
   */
  async findById(id) {
    try {
      const query = 'SELECT id, title, body, created_at FROM items WHERE id = $1';
      const result = await pool.query(query, [id]);
      return result.rows[0] || null;
    } catch (error) {
      logger.error('Failed to fetch item by ID', { id, error: error.message });
      throw new DatabaseError('Failed to retrieve item');
    }
  }

  /**
   * Check database connection
   * @returns {Promise<boolean>}
   */
  async healthCheck() {
    try {
      await pool.query('SELECT 1');
      return true;
    } catch (error) {
      logger.error('Database health check failed', { error: error.message });
      return false;
    }
  }
}

module.exports = ItemRepository;
