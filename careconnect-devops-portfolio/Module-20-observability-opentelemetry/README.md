# Module-20: Observability with OpenTelemetry

**Course section 20 (4 demos) · Status:** ☐ not started  ☐ local lab done  ☐ done on EKS

## What this shows
Traces, logs and metrics for CareConnect with OpenTelemetry (AWS Distro, "ADOT"). The tracing demo uses `booking` (Node.js) calling `appointments` (Java).

| Demo | Where |
|---|---|
| 1. EKS environment with ADOT (operator, collector architecture) | `main.tf` (cert-manager, ADOT add-on, Amazon Managed Prometheus, IAM) |
| 2. Traces with AWS X-Ray (auto-instrumentation, sampling, filtering health checks, service map) | `manifests/` |
| 3. Logs with CloudWatch | `-var enable_container_logs=true` in `main.tf`, then Logs Insights |
| 4. Metrics with Amazon Managed Prometheus and Grafana | `manifests/collector.yaml` (span metrics) and `outputs.tf` |

## Start free: local lab (no AWS)
```
cd Module-20-observability-opentelemetry/local-lab
docker compose up -d
# open the forwarded port 16686 (Jaeger). Look for the "checkout" service; "health-probe" is filtered out by the collector.
docker compose down
```
This shows the pipeline: receivers, processors (batch, **filter health checks**, sampling) and exporters.

## On EKS (costs money, destroy after)
```
cd Module-20-observability-opentelemetry
terraform init && terraform apply                      # needs the cluster from Module-07/13
terraform output amp_remote_write_url                  # paste into manifests/collector.yaml
kubectl apply -f manifests/collector.yaml
kubectl apply -f manifests/instrumentation.yaml
kubectl apply -f manifests/demo-apps.yaml              # after editing the image names
kubectl port-forward svc/booking 9000:80 -n careconnect
curl localhost:9000/                                   # repeat a few times, then open CloudWatch > X-Ray > Service map
```

## Key points to explain
Auto-instrumentation by pod annotation, why filtering health-check spans cut tracing cost, sampling, and why a collector sits between the apps and AWS.

## Screenshots to take
- `docs/screenshots/module-20-jaeger.png`: the local lab traces (and no `health-probe` service)
- `docs/screenshots/module-20-xray-map.png`: X-Ray service map `booking -> appointments` (if run on EKS)
