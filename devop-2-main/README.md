-- DevOps-2 App --

A simple **Node.js app** with a `/health` endpoint, containerized with **Docker**, and a basic **smoke test**.


=> Project Structure

- `app/` → Node.js app code (`app.js`, `package.json`, `test.js`)  
- `Dockerfile` → Docker instructions  
- `docs/app.md` → Usage guide  
- `.github/workflows/ci.yml` → GitHub Actions CI  


=> Run locally

cd app
npm install
npm start

- Open in browser or run:

curl http://localhost:3000/health

- Expected response:

{"status":"OK","message":"Server is healthy"}



=> Smoke Test

npm test


=> Run with Docker

docker build -t devops2-app .
docker run -d -p 3000:3000 --name devops2-container devops2-app
curl http://localhost:3000/health


=> Notes 

- App code is in /app folder
- Dockerfile uses multi-stage build
- CI workflow tests app and builds Docker image automatically