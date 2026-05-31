# Frontend

## Asset Pipeline

Propshaft is used as the asset pipeline (no Sprockets). Static assets in `app/assets/` are fingerprinted and served.

Source: [`Gemfile`](../../Gemfile) (`gem "propshaft"`)

## CSS

Tailwind CSS via `tailwindcss-rails` (no Node.js required). DaisyUI component library layered on top.

Stylesheets loaded in [`app/views/layouts/application.html.erb`](../../app/views/layouts/application.html.erb):
1. `daisyui` — DaisyUI component styles
2. `tailwind` — Tailwind utilities
3. `app` — application-specific overrides (`app/assets/tailwind/application.css`)

In development, `bin/rails tailwindcss:watch[always]` runs in the background to rebuild CSS on change.

DaisyUI reference docs are maintained in [`doc/daisy-ui/`](../daisy-ui/) (note: `doc/`, not `docs/`). Files available: `daisy-ui.md`, `daisy-ui-colors.md`, `daisy-ui-fieldset.md`, `daisy-ui-modal.md`, `daisy-ui-tabs.md`, `daisy-ui-themes.md`, `daisy-ui-tooltips.md`, `daisy-ui-utility-css.md`.

## JavaScript

Import Maps (`importmap-rails`) — no bundler (no webpack/esbuild/vite). Pin configuration: [`config/importmap.rb`](../../config/importmap.rb).

Pins:
- `@hotwired/turbo-rails` → `turbo.min.js`
- `@hotwired/stimulus` → `stimulus.min.js`
- `@hotwired/stimulus-loading` → `stimulus-loading.js`
- `controllers/**` → all Stimulus controllers auto-loaded

Entry point: [`app/javascript/application.js`](../../app/javascript/application.js)

## Turbo

Turbo Drive is active globally. Turbo Frames and Turbo Streams are used for partial page updates.

Implemented stream surfaces:

- Admin user management panel: each section — email, role, password, lifecycle, usage — is independently replaced via `turbo_stream.replace`.
- Dashboard activity feed: `RecordingSession` broadcasts replace the `dashboard_activity` target on the `[workspace, :dashboard]` stream.

## Stimulus Controllers

Located in [`app/javascript/controllers/`](../../app/javascript/controllers/).

| Controller | File | Purpose |
|---|---|---|
| `theme` | `theme_controller.js` | Dark/light mode toggle; persists preference to `localStorage`; respects `prefers-color-scheme` |
| `audio-recorder` | `audio_recorder_controller.js` | Dashboard microphone recording/upload submit flow; chooses compact `MediaRecorder` MIME types; drives non-essential voice aura visualization |
| `hello` | `hello_controller.js` | Scaffold placeholder |

`theme_controller.js` targets: `toggle`, `lightIcon`, `darkIcon`. Applies `data-theme` attribute to `<html>`. Mounted on `<body>` in the main layout.

`audio_recorder_controller.js` targets live in the dashboard recording form. It auto-submits after upload selection or microphone stop, sets `source_kind`, and uses Web Audio analyzer data only for visual feedback. Recording must keep working if visualization is unavailable.

## Icons

[`app/helpers/icon_helper.rb`](../../app/helpers/icon_helper.rb) provides an `icon(name, label: nil, **attrs)` helper.

- Reads SVG files from `app/assets/icons/<name>.svg`.
- Injects HTML attributes (`class`, `aria-label`, `role`, `aria-hidden`) directly into the `<svg>` opening tag.
- Returns empty string if the file does not exist or is not a valid SVG.
- Output is marked `html_safe` after attribute injection.

## Layout

Main layout: [`app/views/layouts/application.html.erb`](../../app/views/layouts/application.html.erb)

Structure:
```html
<html data-theme="light">
  <head>  <!-- CSRF meta, CSP meta, stylesheets, importmap --></head>
  <body data-controller="theme">
    <!-- nav: shared/_logged_in_nav or shared/_logged_out_nav -->
    <main>
      <!-- shared/_flash -->
      <!-- yield (page content) -->
    </main>
    <footer> <!-- copyright, About / Pricing / Demo links --> </footer>
  </body>
</html>
```

## Theme Switching

The `theme` Stimulus controller reads `localStorage["theme_preference"]` on connect, falls back to `prefers-color-scheme`, and sets `document.documentElement.data-theme` to either `"light"` or `"dark"`. DaisyUI reads this attribute to switch theme tokens.

## Localisation

I18n configured. Default locale: `en`. German (`de`) is a valid `preferred_language` on `User`. Locale files: [`config/locales/en.yml`](../../config/locales/en.yml). Only `en.hello` is defined — all other strings are currently hardcoded in views.
