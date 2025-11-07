import express from 'express';

const app = express();
const port = process.env.PORT || 3000;

app.get('/health', (req, res) => {
    res.json({ status: 'OK', message: 'Server is healthy' });
});

app.get('/', (req, res) => {
    const currentTime = new Date().toLocaleString('en-GB', { timeZone: 'Europe/Prague' });
    res.send(`Hello! This is the Team-7 app. <br>🕒 Current time: <strong>${currentTime}</strong>`);
});

app.listen(port, () => {
    console.log(`Server running on http://localhost:${port}`);
});