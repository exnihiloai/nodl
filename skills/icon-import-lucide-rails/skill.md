# Lucide Icon Import (Rails, Local-Only)

Import Lucide icons into this Rails project as local SVG files and render them through a reusable helper.

## Workflow

1. Resolve the requested icon name.
2. Download the SVG from Lucide GitHub into `app/assets/icons/`.
3. Ensure there is a reusable helper for rendering local SVG icons.
4. Apply the icon in the requested ERB view/component.
5. Verify no CDN dependency was introduced.

## 1) Resolve icon name

Use the exact Lucide icon name when possible.

If the user asks for a concept that is not a direct Lucide name, map to the closest icon and state the mapping clearly.
Example: `lemon` -> `citrus`.

## 2) Download icon locally

Prefer the bundled script:

```bash
scripts/import_lucide_icon.sh <lucide-icon-name> <rails-root> [local-name]
```

Examples:

```bash
scripts/import_lucide_icon.sh moon /path/to/rails
scripts/import_lucide_icon.sh citrus /path/to/rails lemon
```

Output target:

- `app/assets/icons/<local-name-or-icon-name>.svg`

## 3) Ensure reusable Rails helper

If missing, add `app/helpers/icon_helper.rb` with a helper that:

1. Reads `app/assets/icons/<name>.svg`.
2. Adds optional classes and accessibility attributes (`aria-label`, `role`).
3. Returns safe HTML for inline SVG rendering.

Keep API small, for example:

```ruby
icon("moon", class: "size-5 text-base-content", label: "Dark mode")
```

## 4) Apply icon in views

Render icons via helper in ERB templates, not via remote `<img>` URLs.

Example:

```erb
<%= icon("citrus", class: "size-5") %>
```

## 5) Verify result

Check these points:

1. Icon file exists in `app/assets/icons/`.
2. View renders icon correctly.
3. No CDN links were added.
4. If replacing an icon, old file references were updated.

## Rails conventions

1. Keep all icon assets in `app/assets/icons`.
2. Prefer inline SVG for theme-aware coloring (`currentColor`).
3. Use Tailwind/DaisyUI classes from the caller, not hardcoded in SVG files.
4. Do not add Node/npm dependencies for icons.
