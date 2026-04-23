# Module: Compliance

> Laws, regulations, and standards applicable to the project.

## How to enable
1. Fill in the sections below with your project's regulations
2. Create a skill in `.claude/skills/` for each regulation (use the template in `_template-skill.md`)
3. Configure the `@compliance-auditor` agent with the active regulations

## Applicable regulations
[SPEC] List your project's regulations. Examples by industry:

### Data protection
| Regulation | Scope | Skill created? |
|-----------|-------|---------------|
| GDPR (EU 2016/679) | Personal data — EU | [ ] |
| CCPA/CPRA | Personal data — California | [ ] |
| LGPD (Law 13.709/2018) | Personal data — Brazil | [ ] |
| HIPAA | Health data — USA | [ ] |
| PIPEDA | Personal data — Canada | [ ] |

### Industry-specific
| Regulation | Scope | Skill created? |
|-----------|-------|---------------|
| PCI-DSS | Payment data | [ ] |
| SOX | Financial controls | [ ] |
| SOC 2 | Trust services criteria | [ ] |

### ISOs
| Standard | Scope | Skill created? |
|---------|-------|---------------|
| ISO 27001 | Information security | [ ] |
| ISO 27701 | Privacy | [ ] |
| ISO 27037 | Digital evidence | [ ] |
| ISO 9001 | Quality | [ ] |
| ISO 42001 | AI governance | [ ] |

## Supporting documents
Create as needed:
- `data-mapping.md` — Personal data mapping
- `dpia.md` — Data Protection Impact Assessment
- `ropa.md` — Record of Processing Activities
- `audit-trail-spec.md` — Audit trail specification
- `data-retention.md` — Data retention policy
- `asset-inventory.md` — Information asset inventory
- `checklists/[regulation]-checklist.md` — Per-regulation checklist

## Integrated workflow
1. PM writes PRD → identifies personal/regulated data
2. Dev implements → compliance skills auto-activate
3. Review → `@compliance-auditor` reviews in the author-critic loop
4. Evidence → audit trail records compliance
