const express = require('express');
const HealthController = require('../controllers/health.controller');

const router = express.Router();
const healthController = new HealthController();

router.get('/status', healthController.status.bind(healthController));
router.get('/ready', healthController.ready.bind(healthController));

module.exports = router;
