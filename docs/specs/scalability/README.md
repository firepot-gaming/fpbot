# Module: Scalability

> Performance, caching, queues, and scaling strategies.

## How to enable
1. Fill in the sections below
2. Create a skill in `.claude/skills/scalability/SKILL.md` if you want auto-invocation

## Load profile
[SPEC] Define for the project:
- Expected concurrent users: [number]
- Requests/second (peak): [number]
- Expected growth: [% per month/year]
- Stored data (1-year projection): [volume]

## Scaling strategy
- [ ] Horizontal (more instances)
- [ ] Vertical (more resources per instance)
- [ ] Hybrid

## Caching
| Layer | Tool | TTL | Invalidation |
|-------|------|-----|-------------|
| CDN | [SPEC] CloudFront/Cloudflare | [SPEC] | [SPEC] |
| Application | [SPEC] Redis/Memcached | [SPEC] | [SPEC] |
| Database | [SPEC] query cache | [SPEC] | [SPEC] |
| Browser | [SPEC] Cache-Control headers | [SPEC] | [SPEC] |

## Queues and async processing
- System: [SPEC] [RabbitMQ / SQS / Redis Streams / Kafka]
- Use cases:
  - [SPEC] [emails, notifications, heavy processing, etc.]
- Dead letter queue: [yes/no]
- Retry policy: [SPEC] [exponential backoff, max retries]

## Database
- Read replicas: [yes/no]
- Connection pooling: [SPEC] [PgBouncer / built-in]
- Sharding: [SPEC] [strategy if applicable]
- Indexes: document critical indexes in ADRs

## Rate limiting
| Endpoint | Limit | Window | Response |
|----------|-------|--------|----------|
| Public API | [SPEC] req | [SPEC] min | 429 |
| Authenticated API | [SPEC] req | [SPEC] min | 429 |
| Webhook | [SPEC] req | [SPEC] min | 429 |

## Performance budget
- First Contentful Paint: < [SPEC] ms
- Time to Interactive: < [SPEC] ms
- API response (p95): < [SPEC] ms
- Bundle size: < [SPEC] KB
