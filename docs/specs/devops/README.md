# Module: DevOps

> CI/CD, Infrastructure as Code, environments, and operations.

## How to enable
1. Fill in the sections below
2. Create a skill in `.claude/skills/devops/SKILL.md` if you want auto-invocation

## CI/CD
- Platform: [SPEC] [GitHub Actions / GitLab CI / CircleCI / Jenkins]
- Pipeline:

```
Push → Lint → Test → Build → [Security Scan] → Deploy Staging → [E2E] → Deploy Prod
```

### Stages
| Stage | Trigger | Required | Timeout |
|-------|---------|----------|---------|
| Lint | Push | Yes | [SPEC] min |
| Unit tests | Push | Yes | [SPEC] min |
| Build | PR | Yes | [SPEC] min |
| Security scan | PR | Yes | [SPEC] min |
| Integration tests | PR | Yes | [SPEC] min |
| Deploy staging | Merge to main | Auto | [SPEC] min |
| E2E | Post-staging | [SPEC] | [SPEC] min |
| Deploy prod | [SPEC] manual/auto | — | [SPEC] min |

## Environments
| Environment | URL | Deploy | Data |
|-------------|-----|--------|------|
| Development | localhost | Local | Fixtures |
| Staging | [SPEC] | Auto (merge main) | Anonymized |
| Production | [SPEC] | [SPEC] manual/auto | Production |

## Infrastructure as Code
- Tool: [SPEC] [Terraform / Pulumi / CDK / CloudFormation]
- Location: [SPEC] [/infra, /terraform, separate repo]
- State: [SPEC] [remote state backend]
- Environments as modules: [SPEC] [yes/no]

## Containers
- Runtime: [SPEC] [Docker / Podman]
- Orchestration: [SPEC] [Kubernetes / ECS / Cloud Run / Fly.io]
- Registry: [SPEC] [ECR / GCR / Docker Hub / GHCR]
- Base image: [SPEC] [image and tag]
- Multi-stage build: [SPEC] [yes/no]
- Vulnerability scan: [SPEC] [Trivy / Snyk / Scout]

## Secrets management
- Vault: [SPEC] [HashiCorp Vault / AWS SM / GCP SM / Azure KV / Doppler]
- Injection: [SPEC] [env vars / mounted secrets / sidecar]
- Rotation: [SPEC] frequency

## Backup and disaster recovery
- RPO (Recovery Point Objective): [SPEC] [how much data can be lost]
- RTO (Recovery Time Objective): [SPEC] [how long to restore]
- Strategy: [SPEC] [daily snapshot / replication / multi-region]
- Recovery test: [SPEC] frequency

## DORA metrics
Track and continuously improve:
- Deployment frequency: [SPEC] [target]
- Lead time for changes: [SPEC] [target]
- Mean time to recovery (MTTR): [SPEC] [target]
- Change failure rate: [SPEC] [target]
