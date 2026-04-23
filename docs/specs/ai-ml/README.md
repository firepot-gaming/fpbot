# Module: AI/ML

> Models, prompts, evals, guardrails, and AI governance.

## How to enable
1. Fill in the sections below
2. Create a skill in `.claude/skills/ai-ml/SKILL.md` if you want auto-invocation

## Models in use
[SPEC] List models:

| Model | Provider | Use | Estimated cost |
|-------|----------|-----|---------------|
| [SPEC] Claude Sonnet | Anthropic | [SPEC] | [SPEC] /month |
| [SPEC] | [SPEC] | [SPEC] | [SPEC] |

## Prompt engineering
- Prompt versioning: [SPEC] [Git / prompt registry / database]
- Format: [SPEC] [system + user / template with variables]
- Location: [SPEC] [src/prompts/ / database / config]
- Prompt review: [SPEC] [required in PR / casual]

## Evaluations (evals)
- Framework: [SPEC] [custom / promptfoo / LangSmith / Braintrust]
- Metrics:
  - Accuracy: [SPEC] [how to measure]
  - Latency: [SPEC] [p50, p95, p99]
  - Cost per call: [SPEC]
  - [SPEC] domain-specific metrics
- Test dataset: [SPEC] [location, size, update frequency]
- Frequency: [SPEC] [on every prompt change / weekly / release]
- Regression test: [SPEC] [compare with previous baseline]

## Guardrails
[SPEC] Define protections:
- Input validation: [SPEC] [max tokens, content filter, PII detection]
- Output validation: [SPEC] [format check, hallucination check, safety filter]
- Rate limiting: [SPEC] [per user, global]
- Cost ceiling: [SPEC] [max per request, per day, per month]
- Fallback: [SPEC] [what happens if the model fails]
- Human-in-the-loop: [SPEC] [which decisions need human approval]

## AI governance
[SPEC] If applicable:
- [ ] ISO 42001 (AI Management)
- [ ] EU AI Act compliance
- [ ] Bias and fairness documentation
- [ ] Model card for each model in production
- [ ] Agent decision audit trail (see compliance module + ISO 27037)

## AI observability
- Prompt logging: [SPEC] [yes, without PII / no]
- Chain/agent tracing: [SPEC] [LangSmith / Helicone / custom]
- Production quality metrics: [SPEC]
- Feedback loop: [SPEC] [how user feedback drives improvements]

## Training data / RAG
[SPEC] If applicable:
- Knowledge base: [SPEC] [location, format]
- Vector store: [SPEC] [Pinecone / Chroma / pgvector / Weaviate]
- Embedding model: [SPEC]
- Chunk strategy: [SPEC] [size, overlap]
- Reindexing: [SPEC] [frequency]
