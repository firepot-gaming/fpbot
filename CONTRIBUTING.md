# Contributing to Claude Proj Blueprint

Thanks for your interest in contributing!

## How to contribute

### Reporting issues
- Use the GitHub issue templates (bug report or feature request)
- Be specific about what you expected vs what happened
- Include your maturity level (L1-L4) for context

### Suggesting new spec modules
1. Open a feature request issue describing the module
2. Include: what it covers, when to enable, example content
3. Once discussed, submit a PR with:
   - `docs/specs/your-module/README.md` following the existing pattern
   - Optional: `.claude/skills/your-module/SKILL.md`

### Improving existing content
- Fix typos, improve clarity, add missing `[SPEC]` examples
- Keep the `[SPEC]` convention — don't replace markers with specific tech choices
- The template should remain stack-agnostic

### Pull requests
1. Fork the repo
2. Create a branch: `git checkout -b feat/my-improvement`
3. Make your changes
4. Submit a PR with a clear description

## Guidelines

- **Keep it generic**: the template works for any stack. Don't add Python-specific or React-specific content outside of examples.
- **Follow the `[SPEC]` pattern**: every project-specific decision should be marked with `[SPEC]`.
- **One module = one concern**: spec modules should be independent and self-contained.
- **Skill descriptions matter**: the `description` field in SKILL.md is what triggers auto-invocation — make it precise.
- **Portuguese is OK**: the template originated in Portuguese. Bilingual content (PT-BR for docs, EN for code) is accepted.

## Code of Conduct

Be kind. Be constructive. We're all here to build better software.
