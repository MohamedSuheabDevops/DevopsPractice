# Section 2: Docker Commands

Do this on your own machine (Docker Desktop). The course uses EC2 + Amazon Linux 2023;
the commands are identical. Install on AL2023 with: `sudo dnf install -y docker && sudo systemctl enable --now docker && sudo usermod -aG docker ec2-user`

## Exercise 1: pull and run

```bash
docker pull nginx:1.27-alpine
docker images
docker run -d --name web -p 8080:80 nginx:1.27-alpine
docker ps
curl.exe http://localhost:8080
docker logs web
docker logs -f web          # Ctrl+C to leave
docker exec -it web sh      # explore, then `exit`
docker inspect web | more
docker inspect --format "{{.NetworkSettings.IPAddress}}" web
docker stop web
docker start web
docker restart web
docker rm -f web
docker rmi nginx:1.27-alpine
```

## Exercise 2: lifecycle

Container states: `created -> running -> paused -> stopped(exited) -> removed`

```bash
docker create --name c1 busybox sleep 300
docker ps -a                   # created
docker start c1                # running
docker pause c1                # paused
docker unpause c1
docker stop c1                 # exited (SIGTERM, then SIGKILL after 10s)
docker rm c1
docker run --rm busybox echo hi          # --rm auto-removes
docker run -d --restart unless-stopped --name r busybox sleep 3600
```

Handy flags: `-d` detach, `-it` interactive TTY, `-p H:C` port, `-e K=V` env, `-v` volume,
`--name`, `--rm`, `--network`, `-m 128m --cpus 0.5` limits.

## Exercise 3: build and push to Docker Hub

```bash
docker login
docker build -f 02-dockerfile-mastery/Dockerfile.good -t <dockerhub-user>/careconnect-demo:1.0.0 apps/python-service
docker tag <dockerhub-user>/careconnect-demo:1.0.0 <dockerhub-user>/careconnect-demo:latest
docker push <dockerhub-user>/careconnect-demo:1.0.0
docker push <dockerhub-user>/careconnect-demo:latest
docker pull <dockerhub-user>/careconnect-demo:1.0.0
docker logout
```

## Exercise 4: cleanup and troubleshooting

```bash
docker ps -a ; docker images ; docker volume ls ; docker network ls
docker system df                 # disk usage
docker container prune           # stopped containers
docker image prune -a            # unused images
docker system prune -af --volumes   # CAREFUL: removes everything unused
docker stats --no-stream
docker top <container>
docker cp <container>:/app/app.py ./app.py.bak
```

Debug a crashing container: `docker ps -a` -> `docker logs <id>` -> `docker inspect <id>` (ExitCode, OOMKilled) -> `docker run -it --entrypoint sh <image>`

## Interview questions

- Container vs VM? (shared kernel, namespaces + cgroups, MBs vs GBs, seconds vs minutes)
- Image vs container? (template vs running instance)
- `docker stop` vs `docker kill`? (SIGTERM + grace period vs SIGKILL)
- What happens when you `docker run`? (pull if missing, create, network, start)
- How do you persist data? (volumes / bind mounts)
- How do you see why a container exited? (`logs`, `inspect` ExitCode)
- What are namespaces and cgroups? (isolation vs resource limits)
