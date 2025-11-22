require('dotenv').config();
const express = require('express');
const cors = require('cors');
const pool = require('./db');


const app = express();

// Enable CORS for all origins (adjust for production)
app.use(cors());
app.use(express.json());


const PORT = process.env.PORT || 3000;


app.get('/status', (req, res) => {
    res.json({ status: 'OK' });
});

app.get('/items', async (req, res) => {
    try {
        const result = await pool.query('SELECT id, title, body, created_at FROM items ORDER BY id');
        res.json(result.rows);
    } catch (err) {
        console.error('DB error', err);
        res.status(500).json({ error: 'Database error' });
    }
});

app.get('/ready', async (req, res) => {
    try {
        await pool.query('SELECT 1');
        res.json({ ready: true });
    } catch (err) {
        res.status(500).json({ ready: false });
    }
});


app.listen(PORT, () => {
    console.log(`API listening on port ${PORT}`);
});