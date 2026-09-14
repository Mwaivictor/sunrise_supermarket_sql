# Security Model

## Authentication

- Every user has an individual account (`users` table) — no shared logins.
- Passwords hashed with bcrypt (via `passlib`), never stored or logged in plaintext.
- Login issues a short-lived JWT access token + longer-lived refresh token. Tokens carry
  `user_id`, `role_id`, and an issued-at claim; they are opaque to the frontend beyond
  that (permissions are re-fetched/re-checked server-side on every request, not trusted
  from the token payload alone for anything sensitive).
- Failed logins, lockout-after-N-attempts, and password reset are Phase 2 hardening
  (see `roadmap.md`); MVP enforces hashing + expiring tokens + HTTPS-only cookie/bearer
  handling.

## Authorization

- Enforced with a FastAPI dependency, `require_permission("issue_stock")`, applied per
  route — never a client-side-only check. The dependency loads the caller's role's
  permission set (via `role_permissions`) on each request.
- Read-only roles (Management, Auditor) are granted only `view_*` permissions in the
  seed data; there is no separate "read-only mode" flag to bypass — they simply have no
  write permissions to check against.
- Cross-department writes are additionally scoped: a Kitchen user's `create_requisition`
  call is constrained server-side to their own department_id; they cannot requisition on
  behalf of another department by manipulating the request body.

## Transaction integrity

- `inventory_transactions` rows are insert-only at the database level (no UPDATE/DELETE
  grants on that table for the application role beyond INSERT/SELECT); corrections are
  new reversal rows. This is enforced with a Postgres `REVOKE UPDATE, DELETE` on the
  table plus a trigger that raises on attempted UPDATE/DELETE, so it holds even if an
  application bug tries to bypass the service layer.

## Audit trail

- `audit_logs` records who/what/when/where/old-value/new-value/reference for every
  state-changing action (login, approval, issue, adjustment, user management change).
  Written by the same service layer that posts the business transaction, in the same
  DB transaction, so an audit row can never be silently skipped by a partial failure.

## Input handling

- All API input validated with Pydantic schemas (type, range, enum membership) before
  it reaches the service layer.
- All DB access via SQLAlchemy parameterized queries — no string-built SQL — eliminating
  SQL injection as a vector by construction.
- CORS restricted to the known frontend origin(s); CSRF is not applicable to the
  token-bearer API pattern used here but cookie-based refresh tokens (if used) are
  `HttpOnly`, `Secure`, `SameSite=Strict`.

## Secrets & config

- DB credentials, JWT signing key, and CORS origins come from environment variables
  (`.env`, never committed — see `.gitignore`), loaded via `pydantic-settings`.

## Deferred to Phase 2 (see `roadmap.md`)

Rate limiting, account lockout policy, MFA, secrets-manager integration, automated
backup verification, and a formal penetration test — all explicitly out of scope for
this MVP but tracked so they aren't forgotten before production go-live.
