import express from 'express';

const app = express();
const port = process.env.PORT || 3000;

app.get('/health', (req, res) => {
    res.json({ status: 'OK', message: 'Server is healthy' });
});

app.get('/', (req, res) => {
    res.send(`
        <html>
        <body>
            <h1>Hello! This is the Team-7 app.</h1>
            <p>🕒 Current time in Prague: <span id="clock"></span></p>

            <script>
                setInterval(() => {
                    const time = new Date().toLocaleString('en-GB', { timeZone: 'Europe/Prague' });
                    document.getElementById('clock').textContent = time;
                }, 1000);
            </script>
        </body>
        </html>
    `);
});

app.listen(port, () => {
    console.log(`Server running on http://localhost:${port}`);
});