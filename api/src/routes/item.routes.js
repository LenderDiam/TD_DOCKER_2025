const express = require('express');
const ItemController = require('../controllers/item.controller');

const router = express.Router();
const itemController = new ItemController();

router.get('/', itemController.getAll.bind(itemController));
router.get('/:id', itemController.getById.bind(itemController));

module.exports = router;
