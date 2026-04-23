# Module: Internationalization (i18n)

> Internationalization, localization, and multi-language support.

## How to enable
1. Fill in the sections below
2. Create a skill in `.claude/skills/i18n/SKILL.md` if you want auto-invocation

## Supported languages
[SPEC] Define:
| Language | Code | Status | Fallback |
|----------|------|--------|----------|
| [SPEC] | [SPEC] en-US | Primary | — |
| [SPEC] | [SPEC] | [SPEC] | en-US |
| [SPEC] | [SPEC] | [SPEC] | [SPEC] |

## Translation strategy
- Library: [SPEC] [i18next / react-intl / next-intl / vue-i18n]
- File format: [SPEC] [JSON / YAML / PO / XLIFF]
- File location: [SPEC] [src/locales/ / public/locales/]
- Management: [SPEC] [manual / Crowdin / Lokalise / Phrase]
- Translation key: [SPEC] [namespace.component.label / flat]

## Code rules
- NEVER hardcode user-visible text — always use a translation key
- Dates: format with `Intl.DateTimeFormat` or equivalent
- Numbers: format with `Intl.NumberFormat`
- Currencies: always display in user's locale
- Pluralization: use ICU message format or equivalent
- RTL: [SPEC] [supported / not applicable]
- Images with text: avoid or have per-language variants

## Language detection
[SPEC] Priority order:
1. Saved user preference
2. Accept-Language header
3. Geolocation (if permitted)
4. Default language (fallback)

## Translation QA
- [ ] Visual test with long text (e.g. German expands ~30%)
- [ ] Check truncation in fixed-width components
- [ ] Test with pseudo-locale during development
