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

`companies` is the tenant table. `accounts.company_id` links an account to its
company; it is nullable while the signup flow does not yet assign one.

## Super admin

A super admin is the **platform operator** — above all tenants, with access to
the back-office at `/super-admin` for managing companies. It is a global
`super_admin` boolean on `accounts`.

The flag is deliberately not settable from the web. Signup cannot reach it, no
permitted-params list includes it, and there is no UI to grant it. Grant it
from the console:

```
bin/rails console
Account.where(email: "you@example.com").update(super_admin: true)
```

Revoke the same way with `super_admin: false`.

Accounts without the flag receive a 404 from every `/super-admin` route rather
than a 403, so the area's existence is not confirmed to anyone probing for it.
