# Modules

A **module** is a self-contained feature area (Backflow Inspections, and
later things like Device Monitoring) that the platform switches on per
tenant. This guide covers how modules work and how to add one. The **Example
module** (`example`) is a working template to copy.

## How modules work

There are three layers:

| Layer | Where | Who changes it |
|---|---|---|
| **What a module is**: name, description, icon, pages | `app/modules/tenant_modules/registry.rb` plus the module's code | developers, in code |
| **Platform status**: Active, Disabled or Planned | `platform_modules` table | super admins, on Platform → Modules |
| **Which tenants have it** | `tenant_modules` table | super admins, on each tenant's edit page |

A tenant can use a module only when it's **assigned to the tenant and Active
platform-wide**.

- **Active:** it can be added to tenants, and tenants who have it use it.
- **Disabled:** it can't be added. Tenants who have it lose access, but keep
  their assignment and data, and get both back when it's Active again.
- **Planned:** it can't be added, and tenants see it as "Coming soon" on their
  overview.

**A module that ships in code with no `platform_modules` row counts as
Disabled.** New modules are therefore off everywhere until a super admin
activates them. All status changes and tenant assignments are logged
(`platform_module_events`, `tenant_module_events`).

## Rules every module follows

- **Generic, never tenant-specific.** No `if tenant.slug == "ruston"`. A
  module may be built for one client first, but any tenant could be
  given it. Behaviour depends on *which modules a tenant has*, never on
  *who the tenant is*.
- **One namespace, named after the key**, for controllers, models, views,
  routes and tests: `Example::`, `app/controllers/example/`,
  `namespace :example`, `test/integration/example/`.
- **Tables are prefixed with the key and carry `tenant_id`**, for example
  `example_items`.
- **Data is reached through the tenant**, e.g.
  `Example::Item.for_tenant(current_tenant)`, never with `.all`, and
  `tenant_id` is set from the session, never from params.
- **Core never depends on a module.** `Tenant` has no association to module
  tables, and core views reach modules only through the registry.
- **Modules don't depend on each other** (yet).

## Adding a module, step by step

Copy the Example module and rename `example` / `Example` to your key, for
example `monitoring` / `Monitoring`.

1. **Registry.** Add a `Definition` to
   `app/modules/tenant_modules/registry.rb` with:
   - `key`
   - `name`
   - `description`
   - `icon`, one of the names in `app/views/shared/_icon.html.erb`
   - `pages`, each `{ label:, path: :route_helper_name }`; the first is the
     module's home

   No migration is needed to declare a module.
2. **Routes.** Add a `namespace :monitoring do ... end` block in
   `config/routes.rb` with a `root`, plus resources for the other pages.
3. **Base controller.** Copy `app/controllers/example/base_controller.rb`. It
   includes `TenantScoped` and `RequiresModule`, calls
   `requires_module :monitoring`, and uses `layout "tenant_module"`. Every
   controller in the module inherits from it.
4. **Data.** Write a migration for `monitoring_*` tables with a non-null
   `tenant_id`, an index on it, and `timestamptz` timestamps. Add a model
   under `app/models/monitoring/` with a `for_tenant` dataset method.
5. **Views.** Put them in `app/views/monitoring/`. Each page renders its own
   `h1`. The layout adds the breadcrumb, and the sidebar lists the module's
   pages automatically.
6. **Tests.** Copy `test/integration/example/items_test.rb`. Cover anonymous
   access going to login, a tenant without the module getting 404, the module
   returning 404 while disabled platform-wide, and each tenant seeing only its
   own data. In tests, turn the module on with
   `PlatformModule.set_status!(:monitoring, "active", by: nil)`.
7. **Ship it.** It deploys as **Disabled**. On **Platform → Modules**, mark it
   **Planned** to show it as Coming soon, or **Active** to start adding it to
   tenants from their edit pages.
