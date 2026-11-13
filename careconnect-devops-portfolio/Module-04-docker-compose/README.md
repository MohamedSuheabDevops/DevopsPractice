# Module-04: Docker Compose (multi-container orchestration)

**Course section 4 (1 comprehensive demo) · Status:** ☐ not started  ☐ done

## What this shows
The whole CareConnect stack on one machine, covering each topic in the course outline:

| Course topic | Where in `compose.yaml` |
|---|---|
| Compose basics with real microservices | 5 services built from `apps/`, one gateway |
| Named volumes | `pgdata`, `mariadbdata` |
| Networks | `frontend` (gateway + services) and `backend` (services + databases) |
| Health checks | every service and every database |
| Scaling with `deploy` | `appointments` runs 2 replicas |
| Startup order with dependencies and conditions | `service_healthy` and `service_completed_successfully` (the `db-migrate` job) |
| Profiles | `adminer` starts only with `--profile tools` |
| Links and aliases | `links:` on the gateway, and the `db` alias on Postgres |

## Run it
```
cd Module-04-docker-compose
cp .env.example .env
docker compose up -d --build
docker compose ps
curl localhost:8080/portal/health
curl localhost:8080/doctors/health
for i in 1 2 3 4; do curl -s localhost:8080/appointments/ ; echo; done     # container name changes: load balancing
docker compose --profile tools up -d                                       # adds Adminer on :8081
docker compose up -d --scale appointments=4
docker compose logs db-migrate
```
Try a failure: `docker compose stop redis`, then `docker compose ps`. `booking` keeps running (it does not use Redis yet) but Redis shows stopped; `docker compose up -d` recovers it.
Clean up: `docker compose down -v`

## Screenshots to take
- `docs/screenshots/module-04-compose-ps.png`: `docker compose ps` with everything `healthy`
- `docs/screenshots/module-04-loadbalancing.png`: the `curl` loop showing different container names
