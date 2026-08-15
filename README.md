# Backflow Inspection

Rails 8 app using **Sequel** (via `sequel-rails`) on PostgreSQL, with Rodauth
for authentication. There is no Active Record — migrations are Sequel
migrations in `db/migrate/`, and models inherit from `Sequel::Model`.

## Setup

Copy `.env.example` to `.env` and fill in the database credentials, then:

```
bin/rails db:create db:migrate
```

The Postgres role needs `CREATEDB` to create the test database.

## Tests

```
bin/rails test
```

The test database defaults to `<DATABASE_NAME>-test`, overridable with
`TEST_DATABASE_NAME`. It runs single-process against a one-connection pool so
each test can wrap its work in a transaction that is rolled back afterwards —
see `test/test_helper.rb`.

## Schema

The schema artifact is `db/structure.sql`, dumped by `pg_dump` on every
migration (`config.sequel.schema_format = :sql` in `config/application.rb`).
Sequel's Ruby schema dumper is lossy for this database — it drops the `citext`
extension and partial indexes — so `db/schema.rb` is not used.

## Multi-tenancy

`tenants` is the tenant table. `accounts.tenant_id` links an account to its
tenant; it is nullable while the signup flow does not yet assign one.

## Super admin

A super admin is the **platform operator** — above all tenants, with access to
the back-office at `/super-admin` for managing tenants. It is a global
`super_admin` boolean on `accounts`.

The flag is granted and revoked from **Accounts** in the back office, by an
existing super admin. Signup cannot reach it and no permitted-params list
includes it, so the panel is the only path. An operator cannot revoke their own
flag, which keeps the last one from locking everybody out.

Bootstrapping the first super admin still happens in the console:

```
bin/rails console
Account.where(email: "you@example.com").update(super_admin: true)
```

Accounts without the flag receive a 404 from every `/super-admin` route rather
than a 403, so the area's existence is not confirmed to anyone probing for it.

## Impersonation

A super admin can impersonate any non-super-admin account from **Accounts** in
the back office, to see and fix what that person sees.

The Rodauth session keeps identifying the operator throughout — only
`current_account` changes — so no remember-me cookie is ever written for the
impersonated account, and stopping is always possible. The back office is
hidden for the duration, since you are acting as a tenant user; the red banner
at the top of every page is the way back.

Every impersonation is recorded in `impersonation_sessions`, and every non-GET
request made during one in `impersonation_events`. Both are append-only and
have no UI; query them from the console:

```
bin/rails console
ImpersonationSession.order(:started_at).last.impersonation_events.map(&:path)
```
