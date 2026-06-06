# Contributing

Thanks for helping keep Nodl clean and maintainable.

## Development

Use the Docker Compose workflow from the repository root:

```sh
make build
make up
make shell
```

Run checks before opening a pull request:

```sh
make lint
make test
make skills-check
```

## Guidelines

- Prefer Rails conventions over custom framework code.
- Keep controllers thin and move growing business logic into models or service objects.
- Keep JavaScript small and local; use Stimulus for targeted interactions.
- Add or update tests for behavior changes.
- Keep external Stripe calls stubbed in tests.
- Do not commit secrets, logs, generated skill outputs, or local runtime artifacts.

## Skills

Canonical skills live under `skills/`. Do not edit generated `.claude/` or `.codex/` files manually.

```sh
make skills
make skills-check
```

## Commits

Keep changes scoped and explain behavior changes clearly. Do not include unrelated refactors in feature or bug-fix pull requests.

## Licensing of contributions

Nodl is source-available under the PolyForm Free Trial License 1.0.0 and offered commercially by ex-nihilo GmbH (see `LICENSES.md`). Because of that dual-licensing model, **external code contributions are not accepted by default** — bug reports, questions, and discussion are very welcome via issues. If you would like to contribute code, contact ex-nihilo GmbH first; any accepted contribution requires a contributor license agreement so the project can continue to be offered under both the free-trial and commercial licenses.
