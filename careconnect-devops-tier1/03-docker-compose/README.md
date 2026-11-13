# Module-04: Docker Compose Practice Kit (CareConnect)

Multi-container orchestration, learned by doing. Each step adds one concept.
Works on Windows (Docker Desktop + VS Code), Mac, Linux.

> Windows PowerShell: use `curl.exe` (not `curl`). Everything else is identical.

## What's inside

```
module-04-docker-compose/
├── README.md
├── .env                         # variables used by the final compose file
├── docker-compose.yml           # FINAL reference: everything combined
├── gateway/nginx.conf           # API gateway: /patients /appointments /doctors
├── services/app/                # tiny Python service (Dockerfile + app.py)
└── steps/
    ├── 01-basics/
    ├── 02-volumes-networks-healthchecks/
    ├── 03-scaling-deploy/
    ├── 04-startup-order/
    └── 05-profiles-links-aliases/
```

The one image runs as `patient-service`, `appointment-service` and `doctor-service`.
Each replies with its name, its **container ID** (so you can see load balancing), and whether its
dependencies (Postgres, Redis, MariaDB) are reachable. `/health` returns 503 until they are.

**How to practise:** do the steps in order. Read the compose file first, predict what will happen,
then run it. Always clean up between steps.

---

## Step 1: Compose basics (real microservices)

```bash
cd steps/01-basics
docker compose up -d --build
docker compose ps
curl.exe http://localhost:8080/patients/hello
docker compose logs gateway
docker compose down
```

Learn: `services`, `build` vs `image`, `ports` vs `expose`, bind-mount config (`volumes`), `environment`, `depends_on`.
Service names become DNS names (the gateway reaches `patient-service`).

Try: change `SERVICE_NAME`, run `docker compose up -d` again and see only that service recreate.

## Step 2: Named volumes, networks, health checks

```bash
cd steps/02-volumes-networks-healthchecks
docker compose up -d --build
docker compose ps                  # watch STATUS go (health: starting) -> (healthy)
curl.exe http://localhost:8080/appointments/health
docker network ls
docker volume ls
docker inspect --format "{{json .State.Health}}" <container-name>
```

Experiments:
1. Prove isolation: `postgres` is only on `backend`. From the gateway, try to reach it:
   `docker compose exec gateway sh -c "nc -zv postgres 5432"` (should fail: different network).
2. Prove the volume persists: `docker compose down` then `up -d` (data kept). `docker compose down -v` deletes the volume.
3. Break a health check: `docker compose stop redis`, then hit `/appointments/health` (503). Start it again, back to 200.

## Step 3: Scaling with `deploy`

```bash
cd steps/03-scaling-deploy
docker compose up -d --build
docker compose ps                  # 3 appointment-service containers
curl.exe http://localhost:8080/appointments/x   # repeat 6 times; watch "container" change
docker compose up -d --scale appointment-service=5
docker compose up -d --scale appointment-service=1
```

Learn: `deploy.replicas`, `resources.limits`, `restart_policy`. `--scale` overrides `replicas`.
Why scaling works: no `container_name`, no fixed host port on the scaled service, and nginx re-resolves Docker DNS (see `resolver` in `gateway/nginx.conf`).

Check limits: `docker stats --no-stream`

## Step 4: Startup order with dependencies and conditions

```bash
cd steps/04-startup-order
docker compose up -d --build
docker compose ps -a               # db-migrate shows Exited (0): that's success
docker compose logs db-migrate
```

Three conditions to know:

| Condition | Meaning |
|---|---|
| `service_started` | container started (default, weakest) |
| `service_healthy` | health check passes |
| `service_completed_successfully` | one-shot job exited with code 0 |

Experiments:
1. Watch the order: `docker compose down` then `docker compose up` (no `-d`) and read the log order.
2. Break the migration: change `CREATE TABLE` to `CREAT TABLE`, run `up -d`. `appointment-service` never starts. Fix it and retry.

## Step 5: Profiles, links, aliases

```bash
cd steps/05-profiles-links-aliases
docker compose up -d --build                      # core only: no adminer/debug/seed
docker compose --profile tools up -d              # + Adminer on http://localhost:8081
docker compose --profile seed up seed-data        # one-shot data load
docker compose --profile debug up -d debug
docker compose exec debug nslookup db             # alias resolves to postgres
docker compose exec debug nslookup appts          # fails: link lives on gateway only
docker compose exec gateway getent hosts appts    # works from gateway
docker compose --profile tools --profile debug down
```

Adminer login: System `PostgreSQL`, Server `db`, user/pass/db from the compose file.

Learn:
- **profiles**: optional services that only start when asked (`--profile x` or `COMPOSE_PROFILES=x`).
- **aliases**: extra DNS names for a service on a specific network.
- **links**: legacy. On user-defined networks every service is already reachable by name, so you rarely need it.

---

## Final: everything together

```bash
cd module-04-docker-compose
docker compose config              # validate + show resolved file (uses .env)
docker compose up -d --build
docker compose ps
curl.exe http://localhost:8080/patients/health
curl.exe http://localhost:8080/appointments/health
curl.exe http://localhost:8080/doctors/health
docker compose --profile tools up -d
docker compose down -v
```

New bits in the final file: YAML anchors (`&svc-health` / `*svc-health`) to reuse a health check, and `.env` variable substitution with defaults (`${APPOINTMENT_REPLICAS:-2}`).

## Challenges (no solutions given, go build them)

1. Add a `notification-service` (same image) that depends on `redis` healthy.
2. Add a third network `monitoring` and a `debug` container that sits on all three.
3. Set `replicas: 3` for `patient-service` and confirm round-robin.
4. Make `db-migrate` also run on `--profile seed` only.
5. Add `restart: unless-stopped` to the databases and test by killing a container.
6. Replace the TCP dependency checks with the real Postgres/Redis clients from your CareConnect code.
7. Add `docker-compose.override.yml` for dev (bind-mount `app.py`, expose ports) and see it auto-merge.
8. Swap the stand-in image for your own CareConnect images from Docker Hub.

## Command cheat sheet

| Task | Command |
|---|---|
| Start (build + detached) | `docker compose up -d --build` |
| Status | `docker compose ps` / `ps -a` |
| Logs (follow) | `docker compose logs -f <svc>` |
| Shell in service | `docker compose exec <svc> sh` |
| One-off container | `docker compose run --rm <svc> sh` |
| Scale | `docker compose up -d --scale <svc>=N` |
| Validate / render | `docker compose config` |
| Stop, keep data | `docker compose down` |
| Stop, delete volumes | `docker compose down -v` |
| Rebuild one service | `docker compose build <svc>` |
| Use profile | `docker compose --profile <name> up -d` |

## Troubleshooting

- **Port 8080 in use:** change `"8080:80"` to `"8081:80"` (or stop the other app).
- **502 from gateway:** that backend service isn't running in this step. Expected for steps with fewer services.
- **Service stuck "Waiting":** `docker compose ps` then `docker compose logs <dependency>` to see which health check fails.
- **Changed `.env` but nothing changed:** run `docker compose up -d` again so containers get recreated.
