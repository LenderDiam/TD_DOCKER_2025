class Item {
  constructor({ id, title, body, created_at }) {
    this.id = id;
    this.title = title;
    this.body = body;
    this.createdAt = created_at;
  }

  /**
   * Convert database row to Item instance
   * @param {Object} row - Database row
   * @returns {Item}
   */
  static fromDatabase(row) {
    return new Item(row);
  }

  /**
   * Convert multiple database rows to Item instances
   * @param {Array} rows - Database rows
   * @returns {Item[]}
   */
  static fromDatabaseArray(rows) {
    return rows.map(row => Item.fromDatabase(row));
  }

  /**
   * Convert Item to JSON response format
   * @returns {Object}
   */
  toJSON() {
    return {
      id: this.id,
      title: this.title,
      body: this.body,
      createdAt: this.createdAt
    };
  }
}

module.exports = Item;
