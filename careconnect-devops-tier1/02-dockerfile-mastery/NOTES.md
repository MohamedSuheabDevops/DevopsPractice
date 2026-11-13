# Section 3: Dockerfile Mastery

All commands run from the **repo root** (`careconnect-devops-tier1/`).

## 1. Instructions cheat sheet

| Instruction | Purpose | Gotcha |
|---|---|---|
| `FROM` | base image | pin a version, never `latest` |
| `LABEL` | metadata | use OCI keys (`org.opencontainers.image.*`) |
| `COPY` | copy files in | prefer over `ADD` |
| `ADD` | COPY + untar + URLs | only use for auto-extract |
| `ARG` | build-time variable | gone at runtime; never put secrets here |
| `ENV` | runtime variable | stays in the image, visible in `docker inspect` |
| `RUN` | run during build | chain commands to cut layers |
| `EXPOSE` | documents the port | does NOT publish it |
| `CMD` | default args/command | easily overridden at `docker run` |
| `ENTRYPOINT` | fixed executable | use with `CMD` for default args |
| `WORKDIR` | set working dir | creates it if missing |
| `HEALTHCHECK` | container health | needed for Compose `service_healthy` |
| `USER` | drop root | use numeric UID |

**CMD vs ENTRYPOINT:** `ENTRYPOINT ["python"]` + `CMD ["app.py"]` runs `python app.py`.
`docker run img other.py` replaces only CMD, so it runs `python other.py`.
Always use the **exec form** (`["a","b"]`), not shell form, so signals (SIGTERM) reach your process.

## 2. Exercise A: spot the problems

```bash
docker build -f 02-dockerfile-mastery/Dockerfile.bad  -t cc-python:bad  apps/python-service
docker build -f 02-dockerfile-mastery/Dockerfile.good -t cc-python:good apps/python-service
docker images | grep cc-python
docker run --rm cc-python:bad  whoami     # root!
docker run --rm --entrypoint whoami cc-python:good   # appuser
```

Problems in `Dockerfile.bad` (try to find them before reading):
1. `python:latest`: unpinned, huge, changes under you.
2. `COPY . /app` before installing deps: any code change busts the pip cache.
3. Runs as **root**.
4. Shell-form `CMD`: PID 1 is `/bin/sh`, SIGTERM isn't forwarded.
5. No `HEALTHCHECK`, no `LABEL`s.
6. `pip install` without `--no-cache-dir` bloats the image.
7. No `.dockerignore`.

## 3. Exercise B: layer caching

```bash
docker build -f 02-dockerfile-mastery/Dockerfile.good -t cc-python:good apps/python-service
# edit apps/python-service/app.py (add a comment), rebuild:
docker build -f 02-dockerfile-mastery/Dockerfile.good -t cc-python:good apps/python-service
```
Rebuild output shows `CACHED` for FROM, requirements and pip install. Only `COPY app.py` re-runs.
Now do the same with `Dockerfile.bad` and watch pip reinstall every time.
Then change `requirements.txt` and see the pip layer rebuild.

**Rule:** order instructions from least to most frequently changing.

## 4. Exercise C: multi-stage builds

```bash
docker build -f 02-dockerfile-mastery/Dockerfile.go-single     -t cc-go:single apps/go-service
docker build -f 02-dockerfile-mastery/Dockerfile.go-multistage -t cc-go:multi  apps/go-service
docker images | grep cc-go            # single ~250MB+, multi ~ a few MB
docker run -d --rm -p 8001:8000 --name go cc-go:multi
curl.exe http://localhost:8001/health
docker stop go
docker build -f 02-dockerfile-mastery/Dockerfile.multistage-python -t cc-python:multi apps/python-service
```
Build one stage only: `docker build --target build -f ... -t cc-go:buildstage apps/go-service`

## 5. Exercise D: security checklist (do it on `cc-python:good`)

```bash
docker run --rm cc-python:good id                       # not root
docker run -d --name hardened --read-only --cap-drop ALL \
  --security-opt no-new-privileges -p 8002:8000 cc-python:good
curl.exe http://localhost:8002/health
docker inspect --format "{{json .State.Health}}" hardened
docker rm -f hardened
```

Checklist: pinned tag/digest, non-root USER, minimal base (alpine/slim/distroless/scratch),
multi-stage, no secrets in `ARG`/`ENV`/layers, `.dockerignore`, `HEALTHCHECK`,
scan images (`docker scout quickview` or `trivy image cc-python:good`).

## Interview questions

- **CMD vs ENTRYPOINT?** See section 1.
- **COPY vs ADD?** ADD can fetch URLs and auto-extract tars; use COPY unless you need that.
- **How do you make builds faster?** Layer order, `.dockerignore`, BuildKit cache mounts, small context.
- **How do you make images smaller/safer?** Multi-stage, slim/distroless/scratch base, non-root, no build tools in final image.
- **Why does `docker history` matter?** Shows layer sizes; a secret removed in a later layer is still in an earlier one.
- **ARG vs ENV?** ARG = build time only. ENV = persists into the running container.
- **Does EXPOSE publish a port?** No, `-p` (or Compose `ports`) does.
