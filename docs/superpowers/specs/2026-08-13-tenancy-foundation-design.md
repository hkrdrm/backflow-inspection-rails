# Tenancy Foundation — Design

**Date:** 2026-08-13
**Status:** Approved for planning

## Purpose

Settle the four decisions that block every remaining view in the workflow
diagram, and land the schema they imply: what a tenant is, what things are
called, how plumbers are modelled, and how roles work.

Nothing in the workflow diagram can be built until these are fixed, because
every list view in it is scope-annotated and every domain table needs to know
which tenant owns its rows.

## Context

Rails 8 on PostgreSQL using **Sequel** (`sequel-rails`), not Active Record.
Migrations are Sequel migrations in `db/migrate/`; the schema artifact is
`db/structure.sql`. Authentication is Rodauth.

Existing domain tables: `accounts` (Rodauth, plus `company_id` and
`super_admin`) and `companies`. Existing app surface: a `/dashboard` sketch and
a `/super-admin` back-office for managing tenants.

The reference material is `mockup.png` (visual design), `assetsheet.png`
(brand assets), and `workflow.png` (the flow being built). These live in the
project root and are gitignored.

The platform-level super admin role is specified separately in
`2026-08-13-super-admin-dashboard-design.md`; this document does not revisit
it beyond renaming the table it manages.

## Decisions

| # | Decision | Choice | Rationale |
|---|---|---|---|
| 1 | Who is the tenant | Water utility / municipality | The admin in the workflow verifies plumber certifications and tracks regulated connections — that is a utility running a backflow prevention program |
| 2 | What the tenant is called | `Tenant` | Names the thing by its job (the isolation boundary); survives a pivot to other tenant types; frees "company" for plumbing outfits like Pike Plumbing Co. |
| 3 | Plumber scope | Belongs to one tenant | The utility supplies its own approved-tester list. Revisit if a tester serving several utilities becomes common |
| 4 | Roles | `role` column on accounts | Every workflow list view is scope-annotated, so the admin/plumber split is coming; one column now avoids retrofitting every scoped controller later |

### Vocabulary

Fixing this because three different things wanted the word "company":

| Term | Means |
|---|---|
| **Tenant** | The paying utility or municipality (City of McComb) |
| **Customer** | A regulated connection the utility oversees |
| **Plumber** | A certified tester; `company_name` holds their employer |
| **Appliance** | A backflow prevention device at a customer location |
| **Inspection** | A test performed on an appliance by a plumber |

Known wrinkle: in a property-adjacent domain "tenant" can also mean a building
occupant. Accepted, because the app models regulated connections rather than
renters, and the word is only ever surfaced in the platform back-office.

### Approaches considered and rejected

- **Global plumbers with per-tenant approval** (a join table holding
  `cert_status` per utility). More accurate for a tester working across several
  utilities, but the utility supplies its own list today. The chosen shape can
  be lifted into that join table later without reshaping other tables.
- **Memberships join table for roles** (one account, several tenants, a role
  in each). Only needed when a person works for two utilities. A `role` column
  does not preclude adding it later.
- **Scoping through associations** (appliance → customer → tenant) instead of a
  direct `tenant_id`. Rejected under "Tenant scoping" below.

## Components

### 1. Rename companies to tenants

One migration: `rename_table :companies, :tenants` and
`rename_column :accounts, :company_id, :tenant_id`. Model `Company` → `Tenant`,
association `many_to_one :tenant`, and the super admin back-office relabelled
to Tenants (routes, controllers, views, README).

PostgreSQL keeps the original index and constraint *names* through a table
rename. That is cosmetic and left alone; renaming them adds churn and risk for
no behavioural gain.

Cheap now: four rows in development, no dependent tables, nothing in production.

### 2. Account roles

`accounts.role`, text, not null, default `'admin'`, with a check constraint
allowing `admin` and `plumber`.

Text rather than the integer enum used by `accounts.status` — that column is
integer because Rodauth requires it. A text status reads directly in `psql` and
in `structure.sql` with no lookup table.

`super_admin` remains a separate boolean. It is platform-level and orthogonal
to the in-tenant role: a super admin has no tenant at all, so it is not a third
value of `role`.

### 3. Tenant scoping

Every domain table carries `tenant_id` directly rather than reaching the tenant
through an association chain. The redundant column buys a real property: a
cross-tenant leak requires actively ignoring the scope, rather than merely
forgetting a join.

Controllers reach data through `current_tenant`, derived from
`current_account.tenant`. Tenant-facing controllers never call `Model.all`.
The super admin back-office is the deliberate exception and queries across
tenants by design.

`accounts.tenant_id` stays nullable, because super admin accounts have no
tenant. Tenant-facing controllers therefore require a present `current_tenant`
and refuse the request without one, rather than the column enforcing it — the
column cannot, while super admins legitimately have none and signup does not
yet assign tenants.

### 4. Plumbers

Tenant-owned reference data, populated by the utility:

```
plumbers
  id           bigint primary key
  tenant_id    not null       → tenants
  account_id   nullable       → accounts
  name         not null
  company_name                  (their employer, e.g. Pike Plumbing Co.)
  email        citext
  phone
  cert_number  not null
  cert_status  not null, default 'pending'   (pending/verified/expired/revoked)
  cert_date    date
  active       not null, default true
  created_at, updated_at
  unique (tenant_id, cert_number)
```

The nullable `account_id` together with the per-tenant unique `cert_number` is
the hinge for later self-registration: a plumber registers, presents a
certification number, and claims the matching row.

**The registration and verification flow is deliberately not designed here.**
It waits until real certification data has been seen, since the matching rules
depend on how those numbers are actually issued and formatted.

## Out of scope

- `customers`, `appliances`, `inspections` — the next slice, in that order
  (inspections depend on both). They inherit the rules above: direct
  `tenant_id`, reached through `current_tenant`.
- Plumber self-registration and certification verification (pending real data).
- The plumber-facing Inspection Form, which needs plumber logins first.
- Reports (90/30/15 day) and the scheduled upcoming-inspection-report task.
- GIS coordinates on appliances. Already decided in principle — capture in the
  field *and* integrate a GIS system — but it belongs with the appliances slice.

## Testing

The 20 existing tests must stay green through the rename.

New coverage:

- `role` defaults to `admin` on a newly created account.
- The check constraint rejects a role outside `admin`/`plumber`.
- `cert_number` uniqueness is per-tenant: the same number is accepted for two
  different tenants and rejected twice within one tenant.
- A plumber belonging to one tenant is not visible through another tenant's
  scope.
- Super admin accounts still reach the back-office with a nil `tenant_id`.
