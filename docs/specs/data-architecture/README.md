# Module: Data Architecture

> Data modeling, pipelines, analytics, and data governance.

## How to enable
1. Fill in the sections below
2. Create a skill in `.claude/skills/data-architecture/SKILL.md` if you want auto-invocation

## Databases
[SPEC] List databases in use:

| Database | Type | Use | Location |
|----------|------|-----|----------|
| [SPEC] PostgreSQL | Relational | Transactional data | [SPEC] |
| [SPEC] Redis | Key-value | Cache, sessions | [SPEC] |
| [SPEC] Elasticsearch | Search | Full-text search | [SPEC] |
| [SPEC] | [SPEC] | [SPEC] | [SPEC] |

## Modeling
- Paradigm: [SPEC] [normalized / event-sourcing / document / graph]
- ERD: keep updated in `docs/architecture/erd.md`
- Naming convention:
  - Tables: [SPEC] [snake_case, plural]
  - Columns: [SPEC] [snake_case]
  - Indexes: [SPEC] [idx_table_column]
  - Foreign keys: [SPEC] [fk_table_reference]
- Soft delete: [SPEC] [yes (deleted_at field) / no]
- Timestamps: [SPEC] [created_at, updated_at on all tables]
- UUIDs vs auto-increment: [SPEC]

## Data pipelines
[SPEC] If applicable:
- ETL/ELT tool: [SPEC] [Airflow / dbt / Prefect / Dagster]
- Data warehouse: [SPEC] [BigQuery / Snowflake / Redshift]
- Sync frequency: [SPEC]
- Analytics schema: [SPEC]

## Event streaming
[SPEC] If applicable:
- Platform: [SPEC] [Kafka / RabbitMQ / SQS / NATS]
- Schema registry: [SPEC] [Avro / Protobuf / JSON Schema]
- Domain events:
  - [SPEC] `user.created`, `user.updated`, `order.placed`
- Dead letter queue: [SPEC]
- Idempotency: [SPEC] [strategy]

## Data governance
- Classification: [public / internal / confidential / restricted]
- Data owner per domain: [SPEC]
- Data catalog: [SPEC] [tool if any]
- Data quality: [SPEC] [checks, validations]
- Lineage: [SPEC] [origin/transformation tracking]

## Analytics
[SPEC] If applicable:
- Tool: [SPEC] [Amplitude / Mixpanel / GA4 / PostHog / Metabase]
- Core events:
  - [SPEC] list product analytics events
- Consent: analytics only with consent (if compliance module is active)
