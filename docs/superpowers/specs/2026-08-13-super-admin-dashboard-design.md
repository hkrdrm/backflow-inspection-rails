# Super Admin Dashboard — Design

**Date:** 2026-08-13
**Status:** Approved for planning

## Purpose

Give the platform operator — the vendor running this app, not a tenant — a
back-office for onboarding and managing companies. This is the first
authenticated, authorized area in the app, so it establishes the pattern the
rest of the multi-tenant system will follow.

## Context

The app is Rails 8 on PostgreSQL using **Sequel** (`sequel-rails`), not Active
Record. Migrations are Sequel migrations in `db/migrate/`. Authentication is
Rodauth via `rodauth-rails`, configured in `app/misc/rodauth_main.rb`.

Existing domain tables: `accounts` (Rodauth) and `companies` (the tenant table,
added 2026-08-12). `accounts.company_id` is a nullable FK to `companies`.

`ApplicationController` already defines `current_account` (delegating to
`rodauth.rails_account`) and `authenticate` (delegating to
`rodauth.require_account`). There is no authenticated area yet — the
`require_account` block in `app/misc/rodauth_app.rb` is commented out.

**Public signup is enabled.** `create_account` is in the Rodauth feature list,
so anyone can create an account. Every decision below assumes an untrusted
account population.

## Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Meaning of super admin | Platform operator, above all tenants | The operator needs cross-tenant visibility; tenant-level admin roles are a separate future concern |
| Storage | `accounts.super_admin` boolean | A global flag matches a global role; no join table needed for a single platform-level privilege |
| Enforcement | Rails controller namespace | ~15 lines using helpers that already exist; a Rodauth secondary config is machinery without a matching need |
| Denial response | 404, not 403 | A 403 confirms the admin area exists to anyone probing for it |
| Granting | Console only | No web-reachable escalation path and no tooling to maintain |
| Deactivation | Flip `active`, never destroy | A tenant's records must not be deletable from a list view |

### Approaches considered and rejected

- **Rodauth secondary configuration** (`configure RodauthAdmin, :admin`): a
  separate auth realm with its own login and views. Appropriate when admins are
  a distinct population; here the admin is the same person logging in normally.
  Nothing in the chosen approach blocks upgrading to this later.
- **Routing constraint**: gate at the route level so `/super-admin` does not
  resolve. Reaching the Rodauth session from a route constraint is awkward and
  makes failures hard to debug.

## Components

### 1. Migration

`add_column :accounts, :super_admin, TrueClass, null: false, default: false`,
in a Sequel migration matching the style of `20260812222010_create_companies.rb`.

Not-null with a default so there is no tri-state ambiguity. No index — the
column is read for the current account only, never used to scan.

### 2. Model

None required. Sequel generates the `super_admin?` predicate from the boolean
column, so `Account#super_admin?` works with no code.

### 3. Authorization

`SuperAdmin::BaseController < ApplicationController`, which every controller in
the namespace inherits from:

- `before_action :authenticate` — Rodauth redirects anonymous visitors to login.
- `before_action :require_super_admin` — renders the static `public/404.html`
  with a 404 status when `current_account&.super_admin?` is falsey. (This app
  has no Active Record, so there is no `RecordNotFound` to raise; the 404 is
  rendered directly.)

Order matters: authentication runs first so an anonymous visitor gets a login
redirect rather than a misleading 404.

### 4. Companies management

`SuperAdmin::CompaniesController` with `index`, `new`, `create`, `edit`,
`update`, and a `deactivate`/`activate` toggle. Routes namespaced under
`/super-admin`. Views follow the existing Tailwind markup conventions in
`app/views/`.

Index shows every company with its account count and active state. The account
count comes from a single grouped query, not per-row counts.

Strong params permit an explicit column list: `name`, `slug`, `email`, `phone`,
`street`, `city`, `state`, `postal_code`, `active`.

### 5. Navigation

A "Super Admin" link in `app/views/layouts/partials/_login_menu.html.erb`,
rendered only when `current_account&.super_admin?`.

### 6. Granting a super admin

Documented in the README:

```
bin/rails console
Account.where(email: "you@example.com").update(super_admin: true)
```

## Security

- Rodauth's `create_account` inserts only email, password hash, and status, so
  `super_admin` is not reachable from public signup.
- The residual risk is future mass assignment (`Account.new(params)`-style).
  Mitigation: explicit permitted-params lists everywhere, and `super_admin`
  appears in none of them.
- Super admins are above tenancy; their `company_id` is expected to be nil.
  Future tenant-scoping code must not assume every account has a company.

## Testing

The test suite does not currently boot, for reasons predating this work:

1. `config/environments/test.rb:32` calls `config.active_storage`, but
   `config/application.rb` loads only a subset of railties for the Sequel
   setup, so Active Storage is undefined.
2. `config/database.yml` has no `test:` section — only development and
   production.

Both are fixed as part of this work, because an authorization boundary is
precisely the thing that needs a regression test.

Tests to write, covering the boundary:

- Anonymous request to a `/super-admin` route redirects to login.
- Logged-in account without the flag receives 404.
- Logged-in account with the flag receives 200.
- `super_admin` defaults to false on a newly created account.
- Company create/update through the controller succeeds; a `super_admin` key
  injected into company params is ignored.

## Out of scope

- Per-company admin roles (a future tenant-level concern).
- Granting or revoking the flag from the web UI.
- Company deletion.
- Tenant scoping of non-admin users to their own company.
