# Module: Observability

> Monitoring, logging, tracing, and alerting.

## How to enable
1. Fill in the sections below
2. Create a skill in `.claude/skills/observability/SKILL.md` if you want auto-invocation

## Three pillars

### Logs
- Format: [SPEC] [structured JSON / plaintext]
- Levels: DEBUG, INFO, WARN, ERROR, FATAL
- Destination: [SPEC] [stdout → collector | Elasticsearch | CloudWatch | Datadog]
- Retention: [SPEC] [period]
- Rules:
  - Never log PII in plaintext
  - Always include: timestamp, request_id, service_name, level
  - Errors: include stack trace and context

### Metrics
- System: [SPEC] [Prometheus / Datadog / CloudWatch / Grafana]
- Required metrics:
  - `http_request_duration_seconds` (histogram)
  - `http_requests_total` (counter, by status code)
  - `active_connections` (gauge)
  - `error_rate` (counter)
  - [SPEC] custom business metrics
- SLIs/SLOs:
  - Latency p99: [SPEC] ms
  - Availability: [SPEC]%
  - Error rate: < [SPEC]%

### Traces
- System: [SPEC] [OpenTelemetry / Jaeger / Datadog APM / X-Ray]
- Propagation: [SPEC] [W3C Trace Context / B3]
- Sample rate: [SPEC] [100% dev / X% prod]
- Required spans: HTTP handler, DB query, external API call

## Alerts
| Condition | Severity | Channel | Response SLA |
|-----------|----------|---------|-------------|
| Error rate > [SPEC]% for 5min | Critical | [SPEC] PagerDuty/Slack | [SPEC] min |
| Latency p99 > [SPEC]ms for 10min | High | [SPEC] | [SPEC] min |
| Disk > 80% | Medium | [SPEC] | [SPEC] h |
| [SPEC] | [SPEC] | [SPEC] | [SPEC] |

## Dashboards
- [SPEC] List required dashboards:
  - [ ] System health overview
  - [ ] Business metrics
  - [ ] Database performance
  - [ ] Errors and exceptions

## Runbooks
Each alert should have a corresponding runbook in `docs/runbooks/`.
