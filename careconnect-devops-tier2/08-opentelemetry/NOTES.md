# Section 20: Observability with OpenTelemetry (concept + free lab)

The AWS version (ADOT, X-Ray, CloudWatch, Amazon Managed Prometheus/Grafana) needs EKS and costs money.
So: **do the free local lab** to learn how an OpenTelemetry Collector pipeline works, then **read the EKS reference** to see where the AWS services plug in.

## The three signals
| Signal | Question it answers | AWS destination in the course |
|---|---|---|
| **Traces** | where did this request spend its time across services? | AWS X-Ray |
| **Logs** | what happened? | CloudWatch Logs (+ Logs Insights) |
| **Metrics** | how is the system trending? | Amazon Managed Prometheus (AMP), viewed in Amazon Managed Grafana (AMG) |

**OpenTelemetry (OTel)** = vendor-neutral standard + SDKs + Collector. **ADOT** = AWS's supported build of it.
**OTLP** = the wire protocol (gRPC :4317, HTTP :4318).

## Collector architecture (memorise)
```
apps (SDK / auto-instrumentation)  --OTLP-->  Collector
                                              receivers  ->  processors  ->  exporters
                                              (otlp)        (batch, filter,    (awsxray, cloudwatchlogs,
                                                             sampling, memory)  prometheusremotewrite, jaeger)
```
Deployment modes: **Deployment** (central gateway), **DaemonSet** (one per node), **Sidecar** (one per pod), **StatefulSet**.
The **OTel Operator** manages collectors (`OpenTelemetryCollector` CR) and agent injection (`Instrumentation` CR). It needs cert-manager.

## Free lab: collector + Jaeger
```bash
cd 08-opentelemetry/local
docker compose up -d
docker compose logs -f otel-collector          # "debug" exporter prints span counts
```
Open **http://localhost:16686** (Jaeger). In *Service*, you should see **checkout** but NOT **health-probe**.
That is the filter processor dropping health-check noise before export: the same trick that cut X-Ray cost by ~85% in the course.

Experiments:
1. Remove `filter/drop-health` from the pipeline, `docker compose restart otel-collector`, and watch `health-probe` appear in Jaeger.
2. Change `sampling_percentage` to 10, compare how many traces appear.
3. Add a second exporter, e.g. `file`, or send `debug` verbosity `detailed` to see span contents.
4. Stop Jaeger: look at the collector log errors and retry/queue behaviour.
5. Add a `resource` processor to stamp `deployment.environment=dev` on everything.

Cleanup: `docker compose down`

> If an image tag fails to pull, check the project's releases and bump the version. `telemetrygen` flags can change between releases (`telemetrygen traces --help`).

## EKS reference (`eks-reference-adot.yaml`)
1. **EKS add-on `adot`** installs the operator (needs **cert-manager** first).
2. `OpenTelemetryCollector` CR configures pipelines; its ServiceAccount gets IAM (X-Ray, CloudWatch Logs, `aps:RemoteWrite`) via **Pod Identity**.
3. **Auto-instrumentation:** annotate the pod template (`instrumentation.opentelemetry.io/inject-java: "true"`) and the operator injects the Java agent via an init container. No code changes. Same for Node.js. (Go needs manual or eBPF instrumentation; Python/.NET also supported.)
4. **Traces** -> `awsxray` exporter -> X-Ray *Service Map* and trace analysis.
5. **Logs** -> `awscloudwatchlogs` -> *Logs Insights* queries, e.g.
   `fields @timestamp, @message | filter @message like /ERROR/ | sort @timestamp desc | limit 20`
6. **Metrics** -> `prometheusremotewrite` (SigV4 auth) -> AMP; **AMG** connects to AMP as a data source; build dashboards (request rate, error rate, latency, plus business KPIs like orders/min).

## Cost control (a favourite interview topic)
- **Filter** noisy spans (health checks, readiness probes).
- **Sample** (head sampling in the SDK/`probabilistic_sampler`; **tail sampling** keeps all errors/slow traces and a % of the rest).
- **Batch** exports. Drop high-cardinality metric labels (user IDs, request IDs as labels explode cost).
- Set log retention on CloudWatch log groups.

## RED / USE (what to put on dashboards)
- **RED** (request-driven services): **R**ate, **E**rrors, **D**uration.
- **USE** (resources): **U**tilization, **S**aturation, **E**rrors.
- Four golden signals: latency, traffic, errors, saturation.

## Interview questions
- Metrics vs logs vs traces: when do you use each?
- What is OpenTelemetry and why use the Collector instead of exporting from the app directly?
- Explain receivers, processors, exporters. Gateway vs agent/sidecar deployment?
- How does auto-instrumentation work in Kubernetes? (operator + annotation + injected agent)
- How did you reduce tracing costs? (filter health checks, sampling)
- Head vs tail sampling?
- Prometheus pull vs OTLP push? What is remote write?
- How would you alert on an SLO breach? (error-rate/latency burn-rate alerts)
