# Module-05: Docker BuildKit and buildx

**Course section 5 (1 comprehensive demo) · Status:** ☐ not started  ☐ done

## What this shows
Building CareConnect images for **both Intel (amd64) and ARM (arm64)**, so one tag runs on a laptop, an Intel server and an AWS Graviton node, plus multi-stage builds for production.

## Run it
```
docker buildx version
docker buildx create --name multi --driver docker-container --use
docker buildx inspect --bootstrap
docker login

# Go service, cross-compiled (fast)
docker buildx build --platform linux/amd64,linux/arm64 \
  -f Module-05-docker-buildkit/Dockerfile.go-multiarch \
  -t <dockerhub-user>/careconnect-doctors:1.0.0 --push apps/doctors

# Node service, built under emulation (slower)
docker buildx build --platform linux/amd64,linux/arm64 \
  -t <dockerhub-user>/careconnect-booking:1.0.0 --push apps/booking

docker buildx imagetools inspect <dockerhub-user>/careconnect-doctors:1.0.0
```
The last command lists `linux/amd64` and `linux/arm64`: that is a **multi-platform manifest**.

## Notes
- Multi-platform images cannot be loaded into the local image store with the default builder, so they are pushed straight to the registry (`--push`).
- The Java services also build multi-arch, but Maven under emulation is slow. The CI workflow builds amd64 only for speed.
- Multi-stage builds (a build stage and a small runtime stage) are already used in every `apps/*/Dockerfile`.

## Screenshots to take
- `docs/screenshots/module-05-imagetools.png`: `imagetools inspect` showing both platforms
- `docs/screenshots/module-05-dockerhub-platforms.png`: the Docker Hub tag page with `amd64` and `arm64`
