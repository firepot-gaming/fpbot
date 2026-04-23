# Module: Versioning

> API versioning, database migrations, semver, and change control.

## How to enable
1. Fill in the sections below
2. Create a skill in `.claude/skills/versioning/SKILL.md` if you want auto-invocation

## Product semver
- Format: `MAJOR.MINOR.PATCH`
- MAJOR: breaking changes
- MINOR: new features (backward compatible)
- PATCH: bugfixes
- Pre-release: `-alpha.1`, `-beta.1`, `-rc.1`
- Release tool: [SPEC] [semantic-release / manual / changeset]

## API versioning
- Strategy: [SPEC] choose one:
  - [ ] URL path: `/api/v1/`, `/api/v2/`
  - [ ] Header: `Accept: application/vnd.app.v1+json`
  - [ ] Query param: `?version=1`
- Deprecation policy:
  - Notice: [SPEC] months before removal
  - Deprecation header: `Deprecation: true`, `Sunset: [date]`
  - Simultaneous version support: max [SPEC] versions
- Changelog: [SPEC] [CHANGELOG.md / releases page / endpoint /changelog]

## Database migrations
- Tool: [SPEC] [Alembic / Prisma Migrate / Flyway / Knex / TypeORM]
- Rules:
  - Every migration must be reversible (up + down)
  - Never alter a migration already applied in production
  - Destructive migrations (DROP, ALTER TYPE) require an ADR
  - Test migrations in staging before production
  - Backups before destructive migrations
- Naming: `YYYYMMDD_HHMMSS_short_description`
- Zero-downtime: [SPEC] strategies:
  - [ ] Expand-contract pattern for schema changes
  - [ ] Background backfill for data
  - [ ] Feature flags for new fields

## Git
- Branch strategy: [SPEC] choose one:
  - [ ] GitHub Flow (main + feature branches)
  - [ ] Git Flow (main + develop + feature + release + hotfix)
  - [ ] Trunk-based (main + short-lived branches)
- Commits: Conventional Commits
- Tags: `v1.0.0` on every release
- Protected branches: [SPEC] [main, develop]
- Merge strategy: [SPEC] [squash / merge commit / rebase]

## Change control
- Breaking change → MAJOR bump + mandatory ADR + migration plan
- New feature → MINOR bump + referenced PRD
- Bugfix → PATCH bump + referenced issue
- Changelog auto-generated from Conventional Commits
