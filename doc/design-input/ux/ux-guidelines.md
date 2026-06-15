# UX Guidelines

Design a user experience that feels simple, clear, calm, and trustworthy.

Good design should make the product feel easy before the user has to think. The interface should guide attention naturally, show what matters most, and make the next useful action obvious. Users should not have to study the screen, guess what something means, or remember how things work.

Prioritize clarity over cleverness. Use familiar patterns, plain language, consistent behavior, and strong visual hierarchy. Avoid surprising interactions, hidden controls, vague labels, unnecessary decoration, and anything that makes the product feel harder than it is.

The best design is not the one that users notice most — it is the one that helps them succeed without friction.

For product wording and terminology, also follow `doc/design-input/language/user-friendly-naming.md`.

## Start minimal

**Default to the smallest UI that completes the task.** Add copy and controls only when user research, errors, legal requirements, or a user story explicitly calls for them.

On the happy path, the UI itself should be the explanation. Do not pad screens with prose.

- One page title is enough. Do not add a subheading that restates the page title.
- Do not add section help paragraphs under headings.
- Do not add hint text under fields for maxlength, format, or obvious inputs — use placeholders, defaults, and server-side validation instead.
- Do not explain platform setup (PWA, Safari, browser permissions) on a settings screen. Show that guidance only when the user hits a relevant error or blocker.

If you are unsure whether text is needed, leave it out first.

## Labels and copy

Labels, buttons, messages, and errors should be specific, direct, and written from the user's point of view. Avoid technical jargon unless users expect it.

**Prefer the shortest clear phrase.** Page title, section heading, and field layout already provide context — labels and buttons should not repeat it.

| Prefer | Avoid |
|--------|-------|
| Speichern / Save | Einstellungen speichern / Save settings (on a settings page) |
| Uhrzeit / Time | Erinnerungszeit / Reminder time |
| Nachricht / Message | Benachrichtigungstext / Notification text |
| Invite team member | Submit |

Use concrete verbs for actions. Avoid vague words like “Proceed” or “Manage” when a specific verb exists.

## Settings and compact forms

Settings pages and small preference forms should feel tight and scannable, especially on phone and PWA home-screen use.

**Reference implementation:** `app/views/settings/show.html.erb` (daily reminder settings).

### Layout

- One page title. One section title only when the page groups unrelated settings.
- Related fields belong on **one row** when they are short and belong together: `[label + input] … [label + input] … [Save]`.
- Use horizontal grouping before stacking fields vertically.
- Size inputs to their content. A time field should be narrow; do not give every field full page width by default.
- Primary action inline with the fields when it fits; otherwise directly below, never separated by explanatory text.

### Controls

- Simple on/off preferences: **checkbox**, not toggle.
- Checkbox label describes what the user **gets**, not what the system does internally (e.g. “Tägliche Erinnerung erhalten”, not “Tägliche Erinnerung aktivieren”).
- Dependent fields are **disabled or de-emphasized** until the opt-in control is checked.
- When turning a feature off, persist immediately (auto-save on uncheck) if the save button would otherwise be disabled.

### Defaults

- Sensible default values in inputs and placeholders (e.g. default reminder message in the placeholder).
- Hidden fields for technical data the user should not edit (e.g. time zone detected client-side).

## Progressive disclosure

Optional or advanced configuration appears **only after** the user opts in.

- Show one entry control first (checkbox, link, “Advanced”).
- Reveal dependent fields when enabled.
- Do not show a full configuration form for a feature that is currently off.
- Rare or destructive actions stay available but must not compete with the main task on the same screen.

## Where text is allowed

| Use on happy path | Do not use on happy path |
|-------------------|--------------------------|
| Page title | Page subheading |
| Section title (if needed) | Section help paragraphs |
| Short field labels | Field hint / helper text |
| Placeholders and default values | Character-limit explanations |
| Button labels | Platform setup guides |
| Flash / toast after action | Inline “how it works” copy |
| Inline errors when something fails | Preventive paragraphs “just in case” |
| Blocking alerts for true blockers (e.g. feature not configured server-side) | |

Errors and blockers should be plain language with a clear recovery path.

## Anti-patterns

Do **not** build these unless a user story explicitly requires them:

- Page subheading that repeats the page title
- Paragraph of help text under every section heading
- Toggle for a simple on/off preference
- Three short fields stacked vertically when one row suffices
- Button label that repeats the page name (“Save settings” on Settings)
- Hint text under inputs for maxlength, format, or optional defaults
- iPhone / PWA / Safari instructions on the form instead of in error states or docs
- Long compound labels when one word plus context is enough
- Menu or dropdown row where only the inner text or icon is clickable while the highlighted row looks fully interactive

## Screen space and mobile-first

Design for phone-first and PWA home-screen use. Every line of static text must earn its place.

- Prefer compact horizontal layouts for related controls.
- Remove clutter before adding explanation.
- Group related things together; show only what matters in the current moment.
- Advanced or rare actions should not compete with the main task for vertical space.

## Main action and hierarchy

Each screen should have a clear purpose and a clear primary action. The user should understand where they are, what they can do, and what will happen next.

Important actions should be easy to find. Destructive or risky actions should be visually distinct and harder to trigger by accident.

## Click targets

Interactive elements must have generous, fully clickable target areas. When a user hovers over a menu item, dropdown option, list row, or button, the entire highlighted or visual boundary must be active and clickable — never restrict the trigger to just the inner text label.

When visual feedback suggests an entire area is interactive, the actual clickable target must match that expectation.

### Dropdown and menu items

DaisyUI `menu` rows often look fully clickable while only the label text responds — users assume the control is broken.

**Rule:** the `<form>` or `<a>` must fill the full row width and height. Padding and hover/active styles belong on that full-width control, not on a narrow inner label.

**Canonical Rails pattern** (same as language switcher and account menu):

```erb
<li class="p-0">
  <%= button_to path,
                form_class: "w-full flex !p-0",
                class: "flex w-full items-center gap-2 px-3 py-1.5 rounded-[inherit] …" %>
</li>
```

- Use `<li class="p-0">` so DaisyUI menu padding does not shrink the hit area.
- `form_class: "w-full flex !p-0"` — the form spans the row.
- Button/link classes include `w-full`, horizontal padding (`px-3 py-1.5`), and `rounded-[inherit]` so hover matches the row shape.

**Reference implementations in this repo:**

- `app/views/shared/_language_switcher.html.erb`
- `app/views/shared/_logged_in_nav.html.erb` (workspace switch, language)
- `app/views/recording_sessions/_delete_button.html.erb` (destructive menu action)

Prefer a shared partial for repeated menu actions instead of one-off markup per screen.

**Gate:** recurring patterns like full-row menu clicks should be backed by a reference partial or an executable check (integration test, lint), not this prose alone — so regressions fail the build with a fix hint.

## Feedback and errors

When users click, save, upload, delete, submit, or change something, the product should respond visibly. Loading, success, failure, empty, disabled, and error states should feel intentional, not like afterthoughts.

Good design prevents mistakes through sensible defaults, constraints, previews, and confirmations — not through paragraphs of preventive help text on every screen.

If an error happens, explain it in plain language and make recovery easy.

## Forgiving flows

Users should be able to go back, undo, cancel, edit, retry, or recover whenever possible. Avoid trapping users in flows. Avoid irreversible actions unless they are clearly explained and confirmed.

## Consistency

Similar things should look and behave similarly. The same words should mean the same things everywhere. Buttons, forms, navigation, icons, spacing, and states should follow a coherent system (DaisyUI + Tailwind patterns in this codebase).

Dropdown and menu rows — links, `button_to`, destructive actions — must use the same full-width row pattern documented under **Click targets → Dropdown and menu items**. Do not invent a slimmer click target per screen.

## Accessibility

The interface should be readable, keyboard-friendly, usable on different screen sizes, and understandable without relying only on color, icons, hover states, or perfect vision. Accessibility is part of good design, not an extra feature.

## Visual style

Use spacing, typography, contrast, alignment, and hierarchy to make the product easier to understand. The UI can look polished, but beauty must not come at the cost of usability. Avoid visual noise, excessive animation, weak contrast, and decorative elements that do not help the user.
