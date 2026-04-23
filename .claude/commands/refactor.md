Safe code refactoring: change structure without changing behavior.

Arguments: $ARGUMENTS (file, module, or description of what to refactor)

Workflow:
1. Activate the `refactor` skill
2. Run tests — must be green before starting
3. Assess: what needs refactoring and why?
4. Choose refactoring type(s) from the catalog (extract, move, rename, simplify, restructure)
5. Plan: list specific steps in order
6. Execute: one refactoring at a time, tests between each
7. Commit: each structural change gets its own commit ("refactor: ...")
8. If files moved → update CLAUDE.md module map and README
9. If architecture changed → create ADR

Tests must pass before AND after every step.
