# Module-02: Docker Commands

**Course section 2 (3 demos) · Status:** ☐ not started  ☐ done

## What this shows
Docker fundamentals using the CareConnect images: install, pull and run, build and push.

## Demo 1: install Docker (Amazon Linux 2023 on EC2)
```
sudo dnf install -y docker
sudo systemctl enable --now docker
sudo usermod -aG docker ec2-user
docker version
```
(Log out and back in so the group applies. In Codespaces Docker is already installed: just run `docker version`.)

## Demo 2: pull from Docker Hub and run containers
```
docker pull nginx:1.27-alpine
docker run -d --name web -p 8080:80 nginx:1.27-alpine
docker ps
curl localhost:8080
docker logs web
docker exec -it web sh
docker inspect --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' web
docker stop web && docker start web
docker rm -f web
docker rmi nginx:1.27-alpine
```

## Demo 3: build CareConnect images and push to Docker Hub
```
docker login
docker build -t <dockerhub-user>/careconnect-portal:1.0.0 apps/portal
docker build -t <dockerhub-user>/careconnect-doctors:1.0.0 apps/doctors
docker images | grep careconnect
docker run -d --name doctors -p 8081:8080 <dockerhub-user>/careconnect-doctors:1.0.0
curl localhost:8081/health
docker push <dockerhub-user>/careconnect-portal:1.0.0
docker push <dockerhub-user>/careconnect-doctors:1.0.0
docker rm -f doctors
```

## Screenshots to take
- `docs/screenshots/module-02-docker-run.png`: `docker ps` and the `curl` output
- `docs/screenshots/module-02-dockerhub.png`: your Docker Hub repositories with the pushed images
