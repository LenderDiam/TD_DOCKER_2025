const { Pool } = require('pg');
const required = (k) => {
if (!process.env[k]) throw new Error(`${k} must be set`);
return process.env[k];
};


const pool = new Pool({
host: process.env.DB_HOST || 'localhost',
port: +(process.env.DB_PORT || 5432),
user: process.env.DB_USER || 'postgres',
password: process.env.DB_PASSWORD || '',
database: process.env.DB_NAME || 'td_db',
max: 10
});


module.exports = pool;