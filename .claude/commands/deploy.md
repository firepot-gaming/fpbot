Run the project deploy checklist.

Workflow:
1. Run tests: [SPEC] test command
2. Run lint: [SPEC] lint command
3. Check for exposed secrets: `grep -r "API_KEY\|SECRET\|PASSWORD" src/ --include="*.py" --include="*.ts" --include="*.tsx"`
4. Check for pending migrations
5. List changes since last tag: `git log $(git describe --tags --abbrev=0)..HEAD --oneline`
6. Generate change summary for release notes

If any step fails, stop and report the problem.
See `docs/runbooks/deploy.md` for specific procedures.
