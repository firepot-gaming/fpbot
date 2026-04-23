Run a specification review on the given code or document.

Arguments: $ARGUMENTS (file or directory to review)

Workflow:
1. Identify the scope: is it code, a PRD, or an ADR?
2. Load active spec modules from docs/specs/
3. For each active module, invoke the corresponding agent:
   - @compliance-auditor → laws, regulations, ISOs
   - @security-auditor → security, OWASP
   - @quality-guardian → quality, observability, tests
4. Consolidate findings by severity (Critical > High > Medium > Low)
5. Generate a report with prioritized remediations

If Critical findings exist: BLOCK.
If High findings exist: WARN.
If only Medium/Low: APPROVE with observations.
