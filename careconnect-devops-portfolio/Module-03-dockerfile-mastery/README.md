# Module-03: Dockerfile Mastery

**Course section 3 · Status:** ☐ not started  ☐ done

## What this shows
The Dockerfile of each CareConnect service, using the course's instructions, security practices, multi-stage builds and layer caching. The real Dockerfiles live next to the code:

| Service | Dockerfile | Highlights |
|---|---|---|
| portal, appointments, billing | `apps/<name>/Dockerfile` | Multi-stage: Maven build, then a small JRE runtime; non-root user; HEALTHCHECK |
| doctors | `apps/doctors/Dockerfile` | Multi-stage: Go compile, then a tiny Alpine runtime |
| booking | `apps/booking/Dockerfile` | Dependencies layer first; `USER node`; HEALTHCHECK |

## Instructions used
`FROM`, `LABEL`, `COPY`, `ARG/ENV`, `RUN`, `WORKDIR`, `EXPOSE`, `USER`, `HEALTHCHECK`, `ENTRYPOINT`, `CMD`.

## Security practices applied
Pinned base image versions, a non-root user (numeric ID), minimal runtime images, no build tools in the final image, a `.dockerignore`, no secrets in layers.

## Run it
```
docker build -t careconnect-doctors:dev apps/doctors
docker build -f Module-03-dockerfile-mastery/examples/Dockerfile.go-single-stage -t careconnect-doctors:single apps/doctors
docker images | grep careconnect-doctors       # compare sizes: multi-stage is far smaller

docker run --rm --entrypoint id careconnect-doctors:dev      # not root (uid=10001)
docker history careconnect-doctors:dev

# layer caching: change a source file, rebuild, and watch the dependency layers say CACHED
echo "// change" >> apps/doctors/main.go
docker build -t careconnect-doctors:dev apps/doctors

docker build -t careconnect-booking:dev apps/booking
docker build -t careconnect-portal:dev apps/portal
```

## Screenshots to take
- `docs/screenshots/module-03-image-sizes.png`: `docker images` showing the single-stage vs multi-stage size difference
- `docs/screenshots/module-03-cache.png`: a rebuild with `CACHED` layers
