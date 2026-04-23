# Module: Testing Strategy

> Test pyramid, QA, and quality strategy.

## How to enable
1. Fill in the sections below
2. The `.claude/skills/testing/SKILL.md` skill already references this module

## Test pyramid
[SPEC] Define proportions and tools:

```
         /  E2E  \          [SPEC]% — [tool]
        /----------\
       / Integration \      [SPEC]% — [tool]
      /----------------\
     /      Unit        \   [SPEC]% — [tool]
    /--------------------\
```

## Tools
| Layer | Backend | Frontend |
|-------|---------|----------|
| Unit | [SPEC] | [SPEC] |
| Integration | [SPEC] | [SPEC] |
| E2E | [SPEC] | [SPEC] Playwright / Cypress |
| Performance | [SPEC] locust / k6 | [SPEC] Lighthouse CI |
| Security | [SPEC] bandit / semgrep | [SPEC] npm audit |

## Patterns
- Naming: `describe` + `it` + AAA (Arrange, Act, Assert)
- Fixtures: [SPEC] [factory pattern / fixtures / builders]
- Mocks: [SPEC] [mock framework, usage policy]
- Test data: [SPEC] [generated / fixtures / snapshot]

## Coverage
- Global minimum: [SPEC]%
- Per-PR minimum (delta): [SPEC]%
- Allowed exclusions: [SPEC] [migrations, config, generated code]
- Coverage tool: [SPEC] [coverage.py / istanbul / c8]

## Tests in CI
| Stage | Trigger | Timeout | Required for merge |
|-------|---------|---------|-------------------|
| Unit | Every push | [SPEC] min | Yes |
| Integration | Every PR | [SPEC] min | Yes |
| E2E | PR to main | [SPEC] min | [SPEC] |
| Performance | Release | [SPEC] min | [SPEC] |
| Security scan | Daily + PR | [SPEC] min | Yes |

## Test environments
| Environment | Data | Purpose |
|-------------|------|---------|
| Local | Fixtures/mocks | Development |
| CI | Ephemeral containers | Automated validation |
| Staging | Anonymized data | Manual validation and E2E |

## Manual QA
[SPEC] Define when needed:
- [ ] Pre-deploy smoke test
- [ ] Pre-release regression test
- [ ] Quarterly exploratory testing
- [ ] Accessibility audit per release
