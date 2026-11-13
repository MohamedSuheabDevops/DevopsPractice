# Section 5: BuildKit and buildx (multi-platform images)

BuildKit is Docker's modern build engine (default in Docker Desktop and Docker 23+).
`buildx` is the CLI that exposes it: multi-platform builds, cache export, build drivers.

**Why multi-platform?** Your Windows laptop is amd64, but AWS Graviton and Apple Silicon are arm64.
An image built for one won't run natively on the other (`exec format error`).
A *multi-arch image* is one tag that points to a manifest list with an image per platform.

## Exercise 1: check setup

```bash
docker buildx version
docker buildx ls
docker buildx create --name multi --driver docker-container --use
docker buildx inspect --bootstrap       # shows supported platforms
```

## Exercise 2: build for two platforms and push (needs Docker Hub login)

Multi-platform images can't be loaded into the local image store with the default driver,
so you push to a registry (or use `--output type=oci,dest=img.tar`).

```bash
docker login
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -f 04-buildkit-buildx/Dockerfile.multiarch \
  -t <dockerhub-user>/careconnect-go:1.0.0 \
  --push apps/go-service

docker buildx imagetools inspect <dockerhub-user>/careconnect-go:1.0.0
```
You should see both `linux/amd64` and `linux/arm64` entries.

Prove it runs on a non-native platform (QEMU emulation, Docker Desktop includes it):
```bash
docker run --rm --platform linux/arm64 <dockerhub-user>/careconnect-go:1.0.0 &
```

## Exercise 3: build the same for your Python service

```bash
docker buildx build --platform linux/amd64,linux/arm64 \
  -f 02-dockerfile-mastery/Dockerfile.good \
  -t <dockerhub-user>/careconnect-python:1.0.0 --push apps/python-service
```
Python builds under emulation for the non-native arch, so it's slower than Go (which cross-compiles).

## Exercise 4: cache mounts and registry cache

```bash
# first build is slow, change requirements.txt, rebuild and compare pip time
docker build -f 04-buildkit-buildx/Dockerfile.cache-mount -t cc-cache:1 apps/python-service

# export cache to the registry (useful in CI)
docker buildx build -f 02-dockerfile-mastery/Dockerfile.good \
  --cache-to type=registry,ref=<dockerhub-user>/careconnect-cache,mode=max \
  --cache-from type=registry,ref=<dockerhub-user>/careconnect-cache \
  -t cc-python:cached apps/python-service
```

## Exercise 5: BuildKit extras

```bash
docker build --progress=plain -f 02-dockerfile-mastery/Dockerfile.good apps/python-service   # full log
docker buildx build --target build -f 02-dockerfile-mastery/Dockerfile.go-multistage -t cc-go:stage apps/go-service
docker buildx du                      # build cache usage
docker buildx prune
```

**Secrets at build time (never `ARG`):**
```dockerfile
RUN --mount=type=secret,id=token cat /run/secrets/token
```
```bash
docker build --secret id=token,src=./token.txt ...
```

## Interview questions

- What is BuildKit and why is it faster? (parallel stages, better caching, skips unused stages)
- How do you build an image for arm64 on an amd64 machine? (buildx + QEMU, or cross-compile with `--platform=$BUILDPLATFORM`)
- What is a manifest list? (one tag, many platform images)
- How do you pass a secret during build safely? (`--mount=type=secret`)
- How do you speed up CI Docker builds? (registry/GHA cache with `--cache-from/--cache-to`)
