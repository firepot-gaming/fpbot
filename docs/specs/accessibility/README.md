# Module: Accessibility

> Digital accessibility, WCAG, and inclusion.

## How to enable
1. Fill in the sections below
2. Create a skill in `.claude/skills/accessibility/SKILL.md` if you want auto-invocation

## Conformance level
[SPEC] Choose:
- [ ] WCAG 2.1 Level A (minimum)
- [ ] WCAG 2.1 Level AA (recommended)
- [ ] WCAG 2.1 Level AAA (excellence)
- [ ] WCAG 2.2 Level AA

## POUR principles

### Perceivable
- [ ] Alt text on all informative images
- [ ] Captions/subtitles on videos
- [ ] Minimum contrast: 4.5:1 (text), 3:1 (large text)
- [ ] Content does not rely on color alone
- [ ] Responsive without information loss (reflow)

### Operable
- [ ] All functionality accessible via keyboard
- [ ] No keyboard traps
- [ ] Skip navigation available
- [ ] Visible focus on all interactive elements
- [ ] Configurable or disableable timeouts

### Understandable
- [ ] Page language declared (`lang`)
- [ ] Labels on all inputs
- [ ] Descriptive error messages near the field
- [ ] Consistent navigation across pages
- [ ] Accessible form validation

### Robust
- [ ] Semantic HTML (`<nav>`, `<main>`, `<article>`, `<aside>`)
- [ ] ARIA roles only when semantic HTML is insufficient
- [ ] Tested with screen readers: [SPEC] [VoiceOver / NVDA / JAWS]
- [ ] Tested with keyboard navigation

## Testing tools
[SPEC] Define:
- Automated: [axe-core / Lighthouse / pa11y]
- Manual: [screen reader, keyboard only, zoom 200%]
- CI: [SPEC] [axe integrated in pipeline]

## Code rules
- Every interactive component must have `aria-label` or associated label
- Modals: trap focus, close with Escape, return focus to trigger
- Dynamic notifications: use `aria-live` regions
- Decorative images: `alt=""`
- Forms: `<fieldset>` + `<legend>` for groups
