# Tenant Modules — Design

**Date:** 2026-11-05
**Status:** Approved for planning

## Purpose

The platform is multi-tenant, and tenants will need very different things. The
City of Ruston, LA needs backflow device inspections. Terrebonne, LA may want
something closer to device monitoring, but that isn't defined yet. Rather than
building one app that every tenant gets in full, the product is split into
**modules**: self-contained feature areas that the platform operator switches
on per tenant.

This design covers only the module *infrastructure*: declaring modules,
assigning them to tenants, and enforcing the assignment. It does not build any
real module's features. It does move the existing backflow dashboard mockup into
a first `backflow` module, which proves the pattern end to end.

## Principles (from the product owner)

1. **Every module is general.** No module is built for a single client. Even a
   heavily customized module is scoped and built so that any tenant could be
   assigned it later. "Built for Terrebonne" means "a general module Terrebonne
   uses first."
2. **Within a shared module, tenants barely differ.** Backflow inspection in
   Louisiana is defined by state regulation, so every LA tenant on the backflow
   module gets the same module. When a client needs a genuinely different
   workflow, that's a different module, not a per-tenant branch inside an
   existing one.
3. **Only the super admin assigns modules.** Tenant admins can't see or change
   their own module assignments.

## Goals

- A code-level list of the modules that exist, each with a stable key, name and
  description.
- A super admin UI for turning each module on or off per tenant.
- Enforcement: a tenant without a module can't reach that module's pages (404),
  and the module's nav items don't render for them.
- An audit trail recording who turned which module on or off for which tenant,
  and when.
- One starter module (`backflow`) exercising the pattern, with tests. Its home
  page is the current backflow dashboard mockup.
- A generic core Dashboard that makes sense for any tenant, whatever modules it
  has.

## Non-goals

- Building any real module's features (inspections, devices, reports).
- Per-tenant module settings or configuration. Principle 2 says these should be
  rare. When the first real need shows up, the likely shape is a `jsonb settings`
  column on `tenant_modules`, but it isn't built now.
- Dashboard widgets contributed by modules. The core Dashboard only links to
  each module's home for now. A widget hook is a possible later step: the
  backflow cards would become that module's widgets, so nothing gets thrown
  away.
- Module dependencies (module B requires module A). Not needed until there are
  two real modules.
- Billing or plans tied to modules.
- Rails engines or gems per module. Modules are namespaces inside the main app
  (product owner's decision). One can be extracted into an engine later if it
  ever needs that.
- Tenant-admin self-service for modules.

## Anti-goals (this would be a failure even if it worked)

- `if tenant.slug == "ruston"` or any other tenant-identity check anywhere in
  module code. Behavior keys off *which modules a tenant has*, never *who the
  tenant is*.
- A module that only makes sense for one tenant's data or vocabulary.
- Turning a module off deletes or orphans tenant data.

## Context

Rails 8 on PostgreSQL using **Sequel** (`sequel-rails`), not Active Record.
Migrations are Sequel migrations in `db/migrate/`, and the schema is dumped to
`db/structure.sql`. Timestamps are `timestamptz` (see
`20260816021500_use_timestamptz_everywhere.rb`). Every new timestamp column must
be too.

Existing pieces this builds on:

- `Tenant` (`app/models/tenant.rb`): `name`, `slug`, `active`.
- `TenantScoped` (`app/controllers/concerns/tenant_scoped.rb`): included by
  every tenant-facing controller. It authenticates, then 404s unless
  `current_tenant&.active?`.
- `ApplicationController#render_not_found`: the app hides things with a 404
  rather than a 403.
- `SuperAdmin::TenantsController`: the patterns to mirror are explicit permitted
  params, `params[:id].to_i`, and state changes kept out of params and given
  their own member actions (`activate` / `deactivate`).
- Impersonation (`app/controllers/concerns/impersonation.rb`): a super admin
  impersonating a tenant account *is* that account for `current_account` /
  `current_tenant`, so they naturally see exactly the impersonated tenant's
  modules. Nothing extra is needed. The super admin area isn't reachable
  mid-impersonation, so whoever toggles a module is always the real operator.
- Sidebar (`app/views/layouts/partials/_app_sidebar.html.erb`): a hard-coded
  `nav_items` list. Items without a `path` render as inert "Not built yet"
  entries.

## Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Where modules are declared | In code, a registry in `app/modules/` (see below) | A module only exists once code exists for it. A DB table of modules could list modules with no code behind them. |
| Where assignments live | DB table `tenant_modules` | Runtime data, changed by the super admin |
| Ruby naming | Registry class `TenantModules::Registry`, definition `TenantModules::Definition`, model `TenantModule` | `Module` is a Ruby core class, so a bare `Module` model or constant is off the table |
| Module key | Lowercase string, e.g. `"backflow"`, also the code namespace (`Backflow::`) | One identifier across DB, code and routes |
| Turning off | Deletes the `tenant_modules` row; module data is untouched | Matches "hidden, not deleted". Turning it back on restores access to everything. |
| Unknown keys in DB | Ignored (treated as not enabled) | Lets a module be removed from code without a crash. The rows stay as history. |
| Enforcement response | 404 via `render_not_found` | Consistent with `TenantScoped` and the super admin area |
| Audit | Append-only `tenant_module_events` table | Mirrors `impersonation_events`. `tenant_modules` shows current state, the events table shows history. |
| UI location | Modules panel on the super admin tenant edit page, one on/off button per module | Assignment is a property of a tenant. Same pattern as activate/deactivate. |
| Dashboard | The current backflow dashboard mockup moves into the `backflow` module as its home page. Core `/dashboard` becomes a generic landing page that links to the tenant's modules. | The current page is all backflow content, so leaving it in core would show backflow to tenants without the module (product owner chose this over module-contributed widgets) |
| Existing tenants | No modules enabled by the migration | The operator enables modules deliberately. Dev seeds may enable `backflow` for a seed tenant. |

## Design

### Module registry

`app/modules/tenant_modules/definition.rb` and `registry.rb` (autoloaded by
Zeitwerk as `TenantModules::Definition` and `TenantModules::Registry`).

A definition is a plain value object:

```ruby
TenantModules::Definition.new(
  key: "backflow",
  name: "Backflow Inspections",
  description: "Backflow prevention device testing and reporting, per Louisiana requirements.",
  home_path: :backflow_root_path,
  nav_items: [
    { label: "Inspections", icon: :calendar, path: :backflow_root_path }
  ]
)
```

`home_path` is the module's landing page, linked from the core Dashboard.
`home_path` and `nav_items` paths are route-helper *names* (symbols), resolved in the view,
so the registry doesn't depend on routes at load time.

The registry holds the definitions in a fixed order and exposes:

- `TenantModules::Registry.all`: every definition, in display order
- `TenantModules::Registry.find(key)`: the definition, or `nil`
- `TenantModules::Registry.keys`

Adding a module means adding one definition to the registry plus its namespaced
code. No migration is needed to declare a module.

### Data model

Migration `create_tenant_modules`:

```
tenant_modules
  id                     bigint pk
  tenant_id              bigint not null fk -> tenants
  module_key             text   not null
  enabled_at             timestamptz not null default now()
  enabled_by_account_id  bigint fk -> accounts   (nullable: seeds/console)
  unique (tenant_id, module_key)

tenant_module_events
  id           bigint pk
  tenant_id    bigint not null fk -> tenants
  module_key   text   not null
  action       text   not null  check (action in ('enabled', 'disabled'))
  account_id   bigint fk -> accounts   (nullable: seeds/console)
  created_at   timestamptz not null default now()
  index (tenant_id)
```

No check constraint lists the valid `module_key` values, because the registry
in code is the source of truth. The model validates the key against
`TenantModules::Registry.keys` on create.

Models:

- `TenantModule`: `many_to_one :tenant`, validates presence and uniqueness of
  `[tenant_id, module_key]`, and validates that `module_key` is in the registry.
- `TenantModuleEvent`: `many_to_one :tenant`, `many_to_one :account`. Append-only.
- `Tenant` gains:
  - `one_to_many :tenant_modules`
  - `module_enabled?(key)`: true only if a row exists *and* the key is in the
    registry
  - `enabled_modules`: the registry definitions this tenant has, in registry
    order
  - `enable_module!(key, by:)` / `disable_module!(key, by:)`: each changes
    `tenant_modules` and writes a `tenant_module_events` row **in one
    transaction**. Both are idempotent: enabling an enabled module, or
    disabling a disabled one, does nothing and writes no event.

`enabled_modules` / `module_enabled?` are called on most requests (the sidebar
plus the guard). They should load the tenant's keys once per request, e.g.
memoized on the `Tenant` instance, which is already memoized as
`current_tenant`.

### Enforcement

New controller concern `app/controllers/concerns/requires_module.rb`:

```ruby
module Backflow
  class BaseController < ApplicationController
    include TenantScoped
    include RequiresModule
    requires_module :backflow
  end
end
```

`requires_module :key` adds a `before_action` that runs **after**
`TenantScoped`'s checks (so an anonymous visitor still goes to login and an
inactive tenant still 404s). It calls `render_not_found` unless
`current_tenant.module_enabled?(key)`. Calling `requires_module` with a key
that isn't in the registry raises at class-load time, so a typo fails loudly in
tests rather than silently 404ing.

Each module has a `<Key>::BaseController` that every controller in the module
inherits from, so no controller in a module can forget the guard.

Routes for a module live in a namespace matching the key:

```ruby
namespace :backflow do
  root to: "home#show"
end
```

Routes are always drawn, and the guard is the only gate. The router doesn't
change per tenant.

### Sidebar

`_app_sidebar.html.erb` becomes core items plus module items:

- **Core** (every tenant): Dashboard, Plumbers, and Settings (still inert), as
  today. Dashboard now links to the generic landing page described below.
- **Module items**: for each of `current_tenant.enabled_modules`, render its
  `nav_items`, resolving each path symbol with `public_send`.

The inert placeholder items that belong to future backflow work (Customers,
Appliances, Inspections, Reports) move off the core list. The backflow module's
definition carries a single live "Inspections" item linking to its home page. The
others come back as real nav items when those features are built inside the
module. *(Builder's call how the core list is extracted. Keep the existing
active-state styling.)*

The super admin "Platform" section is unchanged.

### Super admin UI

On `super_admin/tenants/edit`, below the existing form, add a **Modules** panel.
It's a separate card, not fields inside the tenant form, because module changes
are their own actions. For each `TenantModules::Registry.all` definition it
shows:

- name and description
- status: "Enabled since <date>" or "Off"
- a single button: **Enable** or **Disable**

Routes, nested under the tenant:

```ruby
resources :tenants, ... do
  resources :modules, only: [], param: :key, controller: "tenant_modules" do
    member do
      patch :enable
      patch :disable
    end
  end
end
```

The resulting paths are `PATCH /super-admin/tenants/:tenant_id/modules/:key/enable`
and `.../disable`. `SuperAdmin::TenantModulesController` inherits
`SuperAdmin::BaseController`, finds the tenant with `params[:tenant_id].to_i`
(404 if missing), and 404s if `params[:key]` isn't in the registry. It calls
`enable_module!` / `disable_module!` with `by: current_account`, then redirects
back to the tenant edit page with a notice ("Backflow Inspections enabled for
City of Ruston."). Disabling uses a Turbo confirm that states the data is kept,
e.g. "Turn off Backflow Inspections for City of Ruston? Their data is kept and
returns if you turn it back on."

The tenants index gains a compact "Modules" column listing each tenant's
enabled module names. It's handy for seeing at a glance who has what.

### Starter module: Backflow

Ships with this work so the pattern is real:

- Registry definition `backflow` (above).
- `app/controllers/backflow/base_controller.rb` and `home_controller.rb`.
- **The current dashboard moves here.** `DashboardController`'s `SAMPLE` data
  and `show` logic move to `Backflow::HomeController#show`, and
  `app/views/dashboard/show.html.erb` moves to
  `app/views/backflow/home/show.html.erb`, unchanged apart from paths. It stays
  sample data, with the existing "delete once real models land" comment
  carried over.
- The `namespace :backflow` route, so `/backflow` serves that page.

No models, no migrations. Real backflow work is a separate, later project that
builds inside this namespace.

### Core Dashboard

`/dashboard` (`DashboardController#show`, still `TenantScoped`) stays the
landing page for every tenant user. Rodauth's post-login redirect and the
sidebar logo keep pointing at it, so every tenant always has a valid place to
land. It becomes generic:

- The heading keeps "Welcome back" and adds the tenant's name.
- One card per `current_tenant.enabled_modules`: the module's name and
  description, linking to its `home_path`.
- With no modules enabled, a short note that nothing is set up yet and the
  tenant should contact support. The page must not be blank or broken.

It contains no module-specific content.

### Module code conventions (for future modules)

Written into the doc so every module follows them:

- Everything lives under its key's namespace: `app/controllers/<key>/`,
  `app/models/<key>/`, `app/views/<key>/`, and tests under `test/**/<key>/`.
- Module tables are prefixed `<key>_` (e.g. `backflow_devices`) and carry
  `tenant_id`. All data access goes through `current_tenant`, per
  `TenantScoped`.
- Module code may depend on core (tenants, accounts, plumbers). Core never
  depends on a module. Modules don't depend on each other until module
  dependencies are designed.
- No tenant-identity checks (anti-goal above).

## Testing

Minitest, matching `test/integration/` and `test/models/`:

- **Model:** `enable_module!` / `disable_module!` create and remove rows, write
  exactly one event each, are idempotent, and roll back together. Unknown key
  is rejected. `module_enabled?` ignores DB rows whose key isn't in the
  registry.
- **Guard (integration):** a tenant with `backflow` gets 200 at
  `/backflow`. A tenant without it gets 404. Anonymous goes to login. An
  inactive tenant with the module gets 404. A super admin with no tenant gets
  404.
- **Impersonation:** a super admin impersonating an account in a tenant with
  `backflow` can reach `/backflow`, and one impersonating an account in a tenant
  without it can't.
- **Sidebar:** the Inspections link renders only for tenants with the module.
- **Dashboard:** `test/integration/dashboard_test.rb` keeps its access tests
  (anonymous goes to login, an inactive tenant gets 404, a super admin gets 404,
  the platform section is hidden). New tests: a tenant with `backflow` sees a
  card linking to `/backflow`, a tenant with no modules sees the empty-state
  note, and neither shows backflow sample content (for example "Upcoming
  Inspections") on `/dashboard`. The backflow page's own render test asserts
  that content appears at `/backflow`.
- **Super admin:** enable/disable work and write events attributed to the
  operator. A non-super-admin gets 404 on both actions. An unknown key or
  tenant id gets 404.
- **`requires_module` with an unknown key** raises.

## Delivery

Per the project workflow, this becomes GitHub issues, each delivered through
its own PR against `master`. Suggested split (final split comes from the plan):

1. Registry, `tenant_modules` / `tenant_module_events` tables, models, `Tenant`
   helpers.
2. `RequiresModule` guard, `backflow` module (with the dashboard mockup moved
   into it), generic core Dashboard, module-aware sidebar.
3. Super admin Modules panel, enable/disable actions, tenants index column.

## Left to the builder

- Exact markup and styling of the Modules panel and the placeholder page,
  following the existing super admin screens.
- How the sidebar's core item list and module items are composed in the
  partial.
- Whether dev seeds enable `backflow` for a seed tenant.
