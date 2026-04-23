# Deliverables — Agent Output Validation

Schema files that define required fields in agent output. The `verify-deliverables.sh` hook (SubagentStop) checks agent output against these schemas.

## How it works

1. Agent completes and produces output
2. `SubagentStop` hook triggers `verify-deliverables.sh`
3. Script matches agent name to `{agent-name}.schema`
4. Grep-validates each required field is present in output
5. Warns if fields are missing (never blocks)

## Schema format

One required field per line. Lines starting with `#` are comments.

```
# Required fields in agent output
Category
Severity
Location
Description
Impact
Remediation
```

## Adding a new schema

1. Copy `_template.schema` to `{your-agent-name}.schema`
2. List one required output field per line
3. The hook picks it up automatically — no config needed

## Current schemas

| Schema | Agent | Fields |
|--------|-------|--------|
| `security-auditor.schema` | Security auditor | 7 fields |
| `compliance-auditor.schema` | Compliance auditor | 7 fields |
| `quality-guardian.schema` | Quality guardian | 7 fields |
| `performance-auditor.schema` | Performance auditor | 7 fields |
| `_template.schema` | Template for new agents | 7 fields |
