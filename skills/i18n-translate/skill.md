# i18n Translate

Find and fill the translation **delta** — the keys that exist in the English
source locale but are missing (or empty) in a target locale such as German.

## Role

You are an **AI Localization Engineer** for this Rails app. The app is
**English-first**; `config/locales/en.yml` is the single source of truth. Other
locales (currently `de.yml`) must mirror it exactly.

## When to use

- After adding or changing user-facing copy in `en.yml`.
- When introducing a new locale.
- As a periodic check that every locale is complete.

## Workflow

1. **Detect the delta.** Run the helper script:
   ```bash
   ruby skills/i18n-translate/scripts/i18n_delta.rb            # report all locales
   ruby skills/i18n-translate/scripts/i18n_delta.rb de         # only German
   ruby skills/i18n-translate/scripts/i18n_delta.rb --emit de  # YAML skeleton of missing keys
   ```
   `--emit` prints a nested YAML fragment containing only the missing keys with
   their **English** values, ready to translate in place.

2. **Translate.** Replace each English value with the target-language
   translation. Follow the project voice:
   - Informal German (**"du"**, not "Sie").
   - Keep established **anglicisms**: Dashboard, Login, Workspace, Checkout,
     Upload, Demo, Status, Audit, Service, Plan, Session.
   - Match the tone of surrounding copy (modern, friendly SaaS).

3. **Respect the format.**
   - Keep every `%{placeholder}` **exactly** as in English.
   - Keys ending in `_html` contain HTML — translate only the human text, never
     the tags, attributes, or interpolated markup.
   - Preserve pluralization sub-keys (`one`, `other`).

4. **Merge** the translated fragment into `config/locales/<locale>.yml`, keeping
   the key order aligned with `en.yml` for easy diffing.

5. **Verify.**
   ```bash
   ruby skills/i18n-translate/scripts/i18n_delta.rb <locale>   # must report 0 missing
   make lint
   ```
   Also run the i18n parity test (`test/i18n/locale_parity_test.rb`).

## Critical Rules

- Never invent keys that are not in `en.yml`.
- Never delete or reorder English keys; English is the source.
- Framework-provided number/date keys that only ship for `en` are **ignored**
  by the script's `--app-only` mode; focus on application keys.
- Do not commit unless the user explicitly asks.

## Notes

The script is pure Ruby (uses only the `yaml` stdlib) so it runs without booting
Rails or installing gems.
