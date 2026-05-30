# Security Policy

Nodl is early-stage software. Please report security issues privately instead of opening a public issue.

## Reporting

Until a dedicated security contact is published, send vulnerability details directly to the repository maintainer.

Please include:

- Affected area or route
- Reproduction steps
- Expected impact
- Suggested fix, if known

## Scope

Security-sensitive areas include:

- Authentication and session handling
- Workspace tenancy boundaries
- Admin authorization
- Stripe checkout and webhook validation
- Secret handling and deployment configuration

## Local Safety

Do not commit local secrets. The repository ignores `.env`, `config/master.key`, logs, temp files, and generated skill outputs.
