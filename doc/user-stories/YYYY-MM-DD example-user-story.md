## User Story: General Example

**As a** signed-in user,
**I want to** complete a core workflow end-to-end in one place,
**so that** I can get value from the product quickly without confusion.

### Background
- Users should understand what to do next after login.
- The workflow should be fast, clear, and resilient to validation errors.
- The same flow must work on desktop and mobile.

### In Scope
- One primary page for the workflow (with clear status and next actions).
- Form submission with server-side validation.
- Success and error feedback via consistent UI states.
- Optional partial UI updates with Turbo (without a SPA rewrite).

### Out of Scope
- New billing/subscription logic.
- New third-party integrations.
- Large design-system redesign.

### Acceptance Criteria
- AC-01: Authenticated user can access the workflow page from the main navigation.
- AC-02: Required fields are validated server-side and errors are shown inline.
- AC-03: Successful submission persists data and shows a clear success state.
- AC-04: Workflow state remains consistent after browser refresh.
- AC-05: UI is usable on mobile and desktop breakpoints.
- AC-06: Permission checks prevent access to data outside the current user/workspace context.
- AC-07: Empty, loading, and error states are explicitly represented.
- AC-08: All write operations remain CSRF-protected.

### Technical Notes (Rails)
- Use Rails conventions: RESTful routes, thin controllers, model validations.
- Prefer server-rendered ERB views and reusable partials.
- Use Turbo/Stimulus only where needed for small interaction improvements.
- Keep styling aligned with Tailwind + DaisyUI patterns used in the app.

### Testing
- Integration tests for request/validation/authorization behavior.
- System tests for key happy path and important failure states.
- Include regression coverage for permission boundaries (especially multi-tenant data access).

### Definition of Done
- All acceptance criteria are met.
- New/updated tests are added and passing via `make test`.
- Relevant docs are updated.
- No regressions exist.
