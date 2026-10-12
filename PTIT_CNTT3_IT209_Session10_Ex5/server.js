const http = require('http');

const PORT = parseInt(process.env.PORT, 10) || 8080;
const DB_HOST = process.env.DB_HOST || 'database';
const DB_PORT = process.env.DB_PORT || '5432';
const DB_NAME = process.env.DB_NAME || 'testdb';
const DB_USER = process.env.DB_USER || 'postgres';

const server = http.createServer((req, res) => {
    const url = req.url;

    if (url === '/' || url === '') {
        res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
        res.end(JSON.stringify({
            status: 'success',
            message: 'Hello from Backend Service orchestrated via Docker Compose!',
            service: 'backend',
            database_host: DB_HOST,
            database_port: DB_PORT,
            database_name: DB_NAME,
            database_user: DB_USER,
            timestamp: new Date().toISOString()
        }, null, 2));
    } else if (url === '/health') {
        res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
        res.end(JSON.stringify({
            status: 'healthy',
            service: 'backend',
            uptime_seconds: process.uptime()
        }, null, 2));
    } else {
        res.writeHead(404, { 'Content-Type': 'application/json; charset=utf-8' });
        res.end(JSON.stringify({
            status: 'error',
            message: 'Route not found'
        }, null, 2));
    }
});

server.listen(PORT, '0.0.0.0', () => {
    console.log(`====================================================`);
    console.log(`Backend service is running on port ${PORT}`);
    console.log(`Target database: ${DB_HOST}:${DB_PORT} (DB: ${DB_NAME})`);
    console.log(`Network: backend-net`);
    console.log(`====================================================`);
});
