docker build --tag uptime-kuma:latest .
docker run -d --restart=always -p 3001:3001 -v ./data:/app/data --name exnota-uptime-kuma exnota-uptime-kuma:latest