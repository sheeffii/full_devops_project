import http from 'http';

const options = {
    host: 'localhost',
    port: 3000,
    path: '/health',
    method: 'GET',
};

const req = http.request(options, (res) => {
    let data = '';

    res.on('data', (chunk) => {
        data += chunk;
    });

    res.on('end', () => {
        console.log('Response:', data);
        if (res.statusCode === 200 && data.includes('OK')) {
            console.log('Smoke test passed - app is healthy');
            process.exit(0);
        } else {
            console.error('Smoke test failed');
            process.exit(1);
        }
    });
});

req.on('error', (err) => {
    console.error('Error connecting to server', err.message);
    process.exit(1);
});

req.end();
