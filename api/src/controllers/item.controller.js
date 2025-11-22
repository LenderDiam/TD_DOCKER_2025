const ItemService = require('../services/item.service');

class ItemController {
  constructor(itemService = new ItemService()) {
    this.itemService = itemService;
  }

  /**
   * Get all items
   * @route GET /items
   */
  async getAll(req, res, next) {
    try {
      const items = await this.itemService.getAllItems();
      res.json(items);
    } catch (error) {
      next(error);
    }
  }

  /**
   * Get item by ID
   * @route GET /items/:id
   */
  async getById(req, res, next) {
    try {
      const id = parseInt(req.params.id, 10);
      const item = await this.itemService.getItemById(id);
      res.json(item);
    } catch (error) {
      next(error);
    }
  }
}

module.exports = ItemController;
