import express from 'express';

const app = express();
const port = process.env.PORT || 3000;

app.get('/health', (req, res) => {
    res.json({ status: 'OK', message: 'Server is healthy' });
});

app.get('/', (req, res) => {
    res.send('Hello! This is the DevOps-2 app.');
});

app.listen(port, () => {
    console.log(`Server running on http://localhost:${port}`);
});