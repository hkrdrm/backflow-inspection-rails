# Super Admin User Management — Design

**Date:** 2026-08-14
**Status:** Approved for planning

## Purpose

Give the platform operator a back-office for the people using the platform, not
just the companies they belong to. Two capabilities: managing accounts (create,
edit, close, reopen, reset password, grant and revoke the super admin flag), and
impersonating an account to see and fix what that person sees.

This is the second area in `/super-admin`, following the tenants management
specified in `2026-08-13-super-admin-dashboard-design.md`. It follows that
area's patterns rather than inventing new ones.

## Context

Rails 8 on PostgreSQL using **Sequel** (`sequel-rails`), not Active Record.
Migrations are Sequel migrations in `db/migrate/`. Authentication is Rodauth via
`rodauth-rails`, configured in `app/misc/rodauth_main.rb`.

The `accounts` table already carries every field this panel edits:

| Column | Meaning |
|---|---|
| `email` | citext, Rodauth login |
| `password_hash` | text, bcrypt, written by Rodauth |
| `status` | integer: 1 unverified, 2 verified, 3 closed |
| `tenant_id` | nullable FK; a super admin has none |
| `role` | text, `admin` or `plumber`, check-constrained |
| `super_admin` | boolean, platform-level operator flag |

`SuperAdmin::BaseController` handles authentication and the super admin check,
rendering 404 rather than 403. `ApplicationController` defines `current_account`
(delegating to `rodauth.rails_account`), `current_tenant`, and
`render_not_found`. `SuperAdmin::TenantsController` is the pattern to mirror:
explicit permitted params, `render_not_found` on a missing record, `params[:id].to_i`
so a non-numeric id is a 404 rather than a `PG::InvalidTextRepresentation` 500,
and state changes (`active`) kept out of the params list and given their own
member actions.

Rodauth has `create_account`, `verify_account`, `reset_password`,
`change_password`, and `close_account` enabled, and `after_login { remember_login }`
— every successful Rodauth login writes a remember-me cookie. That last detail
constrains the impersonation design.

## Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Resource name | `Account`, not `User` | The model is `Account`; a second word for one concept is how `User` and `Account` both end up half-existing |
| Account creation | Super admin types the initial password | No mail-delivery dependency in a back-office flow; the operator already holds far greater privilege than one password |
| Deletion | None — close and reopen only | `status = 3` is reversible, is what Rodauth's `close_account` already means, and avoids the FK problem below |
| Impersonation power | Full write access, writes audited | An operator who can only look cannot fix; attribution is preserved by recording rather than by restricting |
| Impersonation mechanism | Session-key swap, Rodauth session untouched | Preserves the real identity, so stopping is always possible; avoids writing a remember-me cookie for the target |
| Audit granularity | Session rows plus one event row per non-GET request | Answers "who, and when" and "what did they change" from the database alone, entirely in the controller layer |
| `super_admin` and `status` | Never in permitted params | Privilege and lifecycle change through dedicated, auditable actions, matching how `active` works for tenants |

### Why no deletion

Every foreign key into `accounts` — `plumbers.account_id` and Rodauth's four key
tables — is `NO ACTION`. A `DELETE` on any account that has ever logged in or is
linked to a plumber raises a constraint violation, so a working delete button
would mean cascading through Rodauth's tables, nullifying `plumbers.account_id`,
and designing the audit tables to survive the disappearance of their own
subject. Closing an account blocks login, is reversible, and costs none of that.
True erasure (a GDPR request) remains a console task, where it can be done with
care.

### Approaches considered and rejected

- **Real Rodauth login as the target** (`account_from_id` then `login`), storing
  the operator's id to switch back. Genuinely indistinguishable from a real
  login — which is the defect: `after_login { remember_login }` would write a
  remember-me cookie for the impersonated account that outlives the session.
- **Signed cookie or DB-backed impersonation token.** Survives restarts and
  works across domains; this app has neither problem.
- **Read-only impersonation**, blocking non-GET requests. Rejected in favour of
  full access with an audit trail: the operator needs to fix things, and
  recording what they did is a better answer than forbidding it.
- **Row-level attribution** (`created_by_account_id` on every domain table).
  Strongest attribution, but touches every table and every write path, and grows
  with each new model.
- **A generic `audit_events` table** covering all super admin actions. A larger
  build than the feature it would be auditing; the impersonation-specific tables
  do not block adding it later.

## Components

### 1. Migration

No change to `accounts`. Two new tables.

`impersonation_sessions`:

| Column | Type | Notes |
|---|---|---|
| `id` | bigint PK | |
| `impersonator_account_id` | bigint NOT NULL → `accounts` | the real super admin |
| `impersonated_account_id` | bigint NOT NULL → `accounts` | the target |
| `tenant_id` | bigint NULL → `tenants` | the target's tenant at the time, denormalized so a later reassignment does not rewrite history |
| `ip_address` | text | |
| `started_at` | timestamptz NOT NULL | |
| `ended_at` | timestamptz NULL | NULL means still live |

`impersonation_events`:

| Column | Type | Notes |
|---|---|---|
| `id` | bigint PK | |
| `impersonation_session_id` | bigint NOT NULL → `impersonation_sessions` | |
| `request_method` | text NOT NULL | |
| `path` | text NOT NULL | |
| `controller_action` | text NOT NULL | e.g. `plumbers#update` |
| `created_at` | timestamptz NOT NULL | |

Two tables rather than one because the questions differ: "who was ever
impersonated, by whom" scans sessions, "what did they change" scans one
session's events. The admin and target identity is stored once per session
rather than once per request.

Indexes on `impersonation_sessions(impersonated_account_id)` and
`impersonation_events(impersonation_session_id)`. Both tables are append-only
from the application's side; stamping `ended_at` is the only update, and nothing
in the UI deletes either.

### 2. Models

`ImpersonationSession` and `ImpersonationEvent`, Sequel models with the
associations implied above.

`Account` gains one method:

```ruby
def set_password(plain)
  self.password_hash = RodauthApp.rodauth.allocate.password_hash(plain)
end
```

Hashing goes through Rodauth rather than raw BCrypt so cost and configuration
cannot drift from what Rodauth itself writes on signup or password reset. This
is the same call `test/fixtures/accounts.yml` already uses, and it is the only
place in the application that knows how a password hash is made.

### 3. Accounts management

`SuperAdmin::AccountsController < SuperAdmin::BaseController`, with `index`,
`new`, `create`, `edit`, `update`, and member actions `close`, `reopen`,
`grant_super_admin`, `revoke_super_admin`, `impersonate`. Routed under the
existing `super_admin` namespace as `resources :accounts`.

**Index.** Every account ordered by email, showing tenant name, role, status,
and a super admin badge. Filtering by tenant and searching by email (`ILIKE`)
are GET params. Tenant names come from a single `Tenant.to_hash(:id, :name)`
lookup rather than a query per row, matching how `@account_counts` is built on
the tenants index.

**Form.** `email`, `tenant_id` (select, blank permitted — that is what a super
admin is), `role` (select over `admin` and `plumber`), and password. On create
the password is required and at least 8 characters, matching Rodauth's
`password_minimum_length`. On edit, blank means unchanged.

**Permitted params:** `email`, `tenant_id`, `role` only. `super_admin` and
`status` are deliberately absent — they change through their own member actions,
so there is one way to escalate a privilege and one way to take an account
offline, and both are auditable.

**Guardrails**, enforced in the controller: an operator cannot close, revoke the
flag from, or impersonate **themselves**, and cannot impersonate an account that
is itself a **super admin**. Self-lockout is a support ticket; peer-to-peer
operator impersonation muddies every audit trail it touches. These redirect back
with an alert rather than rendering 404 — the resource legitimately exists and
is legitimately visible, the request is just not something the panel will do.
404 stays reserved for hiding existence.

Views follow the tenants views' Tailwind conventions.

### 4. Impersonation

**Start.** `POST /super-admin/accounts/:id/impersonate` inserts an
`impersonation_sessions` row and writes `impersonated_account_id` and
`impersonation_session_id` into the Rails session, then redirects to the
dashboard. Rodauth's session is not touched: no `login` call, therefore no
remember-me cookie for the target.

**Identity.** `ApplicationController` gains `true_account`, always
`rodauth.rails_account`. `current_account` returns the impersonated account when
the session key is present, and the real one otherwise. Every existing caller —
`TenantScoped`, `require_super_admin`, the sidebar, the login menu — then behaves
correctly with no edit of its own. A session key pointing at an account that no
longer exists is cleared, and identity falls back to the real account rather
than raising. A *closed* account is still impersonable and stays impersonable
mid-session: "why can this person not log in" is one of the questions the
feature exists to answer, and closed status is enforced by Rodauth at login,
which impersonation does not go through.

**Stop.** `DELETE /impersonation`, handled by a top-level
`ImpersonationsController` **outside** the `SuperAdmin` namespace and authorized
against `true_account.super_admin?`, never `current_account`. This is the point
of keeping the real identity: mid-impersonation `current_account` is the target,
so a route inside the namespace would 404 the operator into being stuck as that
user. It stamps `ended_at`, clears both session keys, and redirects to the
accounts index.

Two properties follow without extra code. Impersonation cannot nest, because
starting one requires reaching the panel, which requires appearing to be a super
admin, which the operator no longer does. And the panel is hidden for the
duration, which is correct: while impersonating you are acting as a tenant user.

**Event logging.** A concern included in `ApplicationController` with an
`after_action` that inserts an `impersonation_events` row for every non-GET
request made while impersonating, including requests that fail validation — an
attempted write is exactly what an audit trail should show.

**Logout.** A `before_logout` hook in `RodauthMain` closes any open impersonation
session. Without it, logging out mid-impersonation strands a row with a NULL
`ended_at` and "still open" stops meaning anything.

**Banner.** A persistent bar in the `app` layout whenever impersonation is
active, naming the account being acted as and offering the Stop button. It is
deliberately hard to miss: an operator who forgets they are impersonating is the
failure mode this feature has.

### 5. Navigation

The sidebar's "Platform" section currently hardcodes a single Tenants link. It
becomes a two-item list built the way `nav_items` already is, so a third
back-office page is a line rather than a copied block.

## Security

- `super_admin` remains unreachable through any permitted-params list. Granting
  moves from console-only to a web action, so it gets its own route, its own
  guardrail against self-revocation, and a super admin badge on the index that
  makes the current holders obvious at a glance.
- Impersonation never authenticates as the target. The Rodauth session continues
  to identify the operator for the entire duration, so no remember-me cookie,
  password reset, or login-change flow can be triggered as the target by a
  stale session.
- The stop route authorizes on `true_account`, so it is reachable exactly when
  impersonation is active and by exactly the operator who started it.
- Closing an account sets `status = 3`; Rodauth already refuses login for closed
  accounts, so account lifecycle is enforced by the auth layer rather than by
  this panel's own checks.
- Impersonation of a super admin is refused, so the feature cannot be used to
  reach another operator's privileges.

## Testing

Integration tests in the style of `test/integration/super_admin_tenants_test.rb`.

Accounts management:

- Anonymous request to an accounts route redirects to login; a logged-in
  non-super-admin gets 404.
- Create with a password produces an account that can log in with it.
- Update with a blank password leaves `password_hash` unchanged.
- `super_admin` and `status` injected into account params are ignored.
- Close blocks login; reopen restores it.
- Grant and revoke change the flag; revoking your own is refused.

Impersonation:

- Starting inserts a session row and switches `current_account`.
- A non-GET request while impersonating inserts an event row; a GET does not.
- The super admin panel returns 404 while impersonating.
- Stopping stamps `ended_at`, clears the session, and restores the real account.
- Impersonating yourself, or another super admin, is refused.
- Impersonating a closed account is permitted.
- Logging out while impersonating closes the open session row.
- A session key pointing at a removed account falls back to the real account.

Model test: `Account#set_password` writes a hash Rodauth accepts at login.

## Out of scope

- Hard deletion of accounts.
- Invite or password-reset emails sent from the panel.
- A generic audit log covering non-impersonation super admin actions.
- Tenant-level user management (a tenant admin managing their own staff).
- Viewing impersonation history in the UI; the tables are queried from the
  console until there is a reason to build a screen.
