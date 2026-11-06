# Tenant Modules Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the super admin switch self-contained feature modules on and off per tenant, enforce that in routes and navigation, and move the backflow dashboard mockup into a first `backflow` module.

**Architecture:** Modules are declared in code (`TenantModules::Registry` under `app/modules/`). Assignments live in a `tenant_modules` table, and changes are recorded in an append-only `tenant_module_events` table. Each module is a namespace (`Backflow::`) whose controllers inherit a base controller that runs a `requires_module` guard (404 when the tenant doesn't have the module). The sidebar and the core `/dashboard` are built from the tenant's enabled modules.

**Tech Stack:** Rails 8, Sequel (`sequel-rails`, not Active Record), PostgreSQL, Rodauth, Minitest, Tailwind.

**Spec:** `docs/superpowers/specs/2026-11-05-tenant-modules-design.md`

## Global Constraints

- Sequel, not Active Record: models are `Sequel::Model`, migrations are `Sequel.migration`, and the schema dumps to `db/structure.sql` (`config.sequel.schema_format = :sql`). Commit `db/structure.sql` with every migration.
- Every timestamp column is `timestamptz`. `test/models/schema_test.rb` fails otherwise. Stamp timestamps in Ruby with `Time.current`, not the column default (see the comment in `app/controllers/concerns/impersonation.rb#record_impersonated_write`).
- Hidden things return 404 via `render_not_found`, never 403.
- Ids from params go through `.to_i` before lookup.
- No tenant-identity checks (`slug ==`, `name ==`, tenant id literals) anywhere in module code or the guard.
- Core code never references a specific module's constants (`Backflow::`). It goes through `TenantModules::Registry` and `Tenant#enabled_modules`.
- Module keys are lowercase strings. The first and only module is `"backflow"`, named `"Backflow Inspections"`, described as `"Backflow prevention device testing and reporting, per Louisiana requirements."`
- Run the suite with `bin/rails test`. Lint with `bin/rubocop`. Both must be clean before each commit.
- Delivery: three GitHub issues, one branch and PR each. Branch names use the `ms-` prefix. The PRs are stacked: PR 1 targets `master`, PR 2 targets PR 1's branch, PR 3 targets PR 2's, and each is retargeted to `master` as the one below it merges. Commit messages end with the `Co-Authored-By` line from the session.

## Review Focus

1. **A `tenant_modules` row whose key is no longer in the registry** (a module removed from code). `/dashboard`, the sidebar, and the super admin tenant pages must render normally and just not show it. Test added to Task 2 and Task 4.
2. **Double-submitting Enable** (double click, two tabs). The second call is a no-op with no second event and no 500, even if it races past the existence check into the unique index. Test added to Task 2.
3. **Disable, then enable again.** Access comes back, and the history shows three events in order (enabled, disabled, enabled). Test added to Task 2.
4. **Enabling a module on an inactive tenant.** This is allowed, because an operator sets a tenant up before activating it. The tenant still gets 404 everywhere until it's activated. Test added to Task 5.
5. **A tenant admin (not super admin) PATCHing enable for their own tenant** gets 404 and no row changes. Test added to Task 5.

---

## Issue 1 (#15) — Module registry and assignment storage (branch `ms-tenant-modules-registry`)

### Task 1: Module registry

**Files:**
- Create: `app/modules/tenant_modules/definition.rb`
- Create: `app/modules/tenant_modules/registry.rb`
- Test: `test/modules/tenant_modules/registry_test.rb`

**Interfaces:**
- Produces:
  - `TenantModules::Definition`: `Data.define(:key, :name, :description, :home_path, :nav_items)`. `key` is a String, `home_path` is a Symbol route-helper name, and `nav_items` is an Array of `{ label: String, icon: Symbol, path: Symbol }` hashes.
  - `TenantModules::Registry.all -> Array<Definition>` (frozen, display order)
  - `TenantModules::Registry.find(key) -> Definition | nil`, which accepts a String or Symbol. Matching is exact, so `"Backflow"` returns nil.
  - `TenantModules::Registry.keys -> Array<String>`
  - The `backflow` definition: `home_path: :backflow_root_path`, `nav_items: [ { label: "Inspections", icon: :calendar, path: :backflow_root_path } ]`

- [ ] **Step 1: Write the failing test.** `class TenantModules::RegistryTest < ActiveSupport::TestCase` with:
  - `test "declares the backflow module"`: `find("backflow")` has `name == "Backflow Inspections"` and `home_path == :backflow_root_path`
  - `test "finds by symbol or string"`: `assert_equal find("backflow"), find(:backflow)`
  - `test "unknown and differently cased keys are not found"`: `assert_nil find("nope")`, `assert_nil find("Backflow")`
  - `test "keys are unique lowercase strings"`: `keys == keys.uniq`, and every key matches `/\A[a-z][a-z0-9_]*\z/`
  - `test "keys follow all"`: `assert_equal all.map(&:key), keys`
- [ ] **Step 2: Run** `bin/rails test test/modules/tenant_modules/registry_test.rb`. Expected: FAIL with `NameError: uninitialized constant TenantModules`. If instead the `test/modules` directory isn't picked up, confirm with `bin/rails test test/modules` and run that path directly. `bin/rails test` with no arguments runs everything under `test/` except `test/system`.
- [ ] **Step 3: Implement** both files. Zeitwerk autoloads `app/modules` as a root, so no config is needed. Verify with `bin/rails runner 'p TenantModules::Registry.keys'` → `["backflow"]`. Add a file comment in `registry.rb` stating the rule: adding a module means adding a definition here plus its namespaced code, and no migration.
- [ ] **Step 4: Run** the test. Expected: PASS.
- [ ] **Step 5: Commit.** First commit the spec and this plan on the branch (`git add docs/superpowers`, message "Design and plan tenant modules"), then `git add app/modules test/modules` and commit "Declare modules in a code registry".

### Task 2: Assignment tables, models, `Tenant` helpers

**Files:**
- Create: `db/migrate/20261105120000_create_tenant_modules.rb`
- Modify: `db/structure.sql` (regenerated)
- Create: `app/models/tenant_module.rb`, `app/models/tenant_module_event.rb`
- Modify: `app/models/tenant.rb`
- Test: `test/models/tenant_module_test.rb`

**Interfaces:**
- Consumes: `TenantModules::Registry.find`, `.keys`, `.all`
- Produces:
  - Tables exactly as in the spec's *Data model* section. Timestamps are `timestamptz`, FKs are `Bignum`, there's a unique index on `[:tenant_id, :module_key]`, an index on `tenant_module_events.tenant_id`, and a check constraint `tenant_module_events_action_valid` with `action: %w[enabled disabled]`.
  - `TenantModule` (`many_to_one :tenant`). Validates presence of `tenant_id, module_key`, uniqueness of `[:tenant_id, :module_key]`, and `module_key` ∈ `Registry.keys` (`validates_includes`).
  - `TenantModuleEvent` (`many_to_one :tenant`, `many_to_one :account`)
  - `Tenant#tenant_modules` (`one_to_many`)
  - `Tenant#module_enabled?(key) -> Boolean`
  - `Tenant#enabled_modules -> Array<TenantModules::Definition>`, in registry order, skipping keys not in the registry
  - `Tenant#module_enabled_at(key) -> Time | nil`, used by the super admin panel
  - `Tenant#enable_module!(key, by:) -> Boolean`, true if it changed something
  - `Tenant#disable_module!(key, by:) -> Boolean`
  - Both bang methods raise `ArgumentError` for a key not in the registry. `by:` is an `Account` or `nil`.

- [ ] **Step 1: Write the migration** (`create_table`, using `column :enabled_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP` and the same for `created_at`). Run `bin/rails db:migrate` and confirm `db/structure.sql` now has both tables, then run `RAILS_ENV=test bin/rails db:test:prepare`.
- [ ] **Step 2: Write the failing tests** in `class TenantModuleTest < ActiveSupport::TestCase` (setup: `@tenant = Tenant.create(name: "Acme Water", slug: "acme")`, `@boss = create_account(email: "boss@example.com", super_admin: true)`):
  - `"a new tenant has no modules"`: `assert_not @tenant.module_enabled?(:backflow)` and `assert_empty @tenant.enabled_modules`
  - `"enabling records the module and one event"`: `assert @tenant.enable_module!(:backflow, by: @boss)`. Then `assert @tenant.refresh.module_enabled?("backflow")`, the `TenantModule` row has `enabled_by_account_id == @boss.id`, and there's exactly one `TenantModuleEvent` with `action == "enabled"`, `account_id == @boss.id`, `module_key == "backflow"`.
  - `"enabling twice is a no-op"`: the second call returns `false` and the event count stays 1
  - `"a unique-index race is treated as already enabled"`: insert the `tenant_modules` row directly with `TenantModule.dataset.insert(...)`, then stub the existence check so it misses (e.g. `@tenant.stub(:module_enabled?, false)`). `enable_module!` returns `false`, doesn't raise, and writes no event.
  - `"disabling removes access, keeps history"`: enable, then `assert @tenant.disable_module!(:backflow, by: @boss)`. Not enabled afterwards, events are `["enabled", "disabled"]`.
  - `"disabling a module that is off is a no-op"`: returns `false`, no event
  - `"re-enabling restores access with full history"`: enable → disable → enable, events are `["enabled", "disabled", "enabled"]`, enabled again
  - `"unknown keys raise"`: `assert_raises(ArgumentError) { @tenant.enable_module!(:nope, by: @boss) }`, same for disable
  - `"rows for modules no longer in the registry are ignored"`: `TenantModule.dataset.insert(tenant_id: @tenant.id, module_key: "retired", enabled_at: Time.current)`. Then `assert_not @tenant.refresh.module_enabled?("retired")` and `assert_empty @tenant.enabled_modules`.
  - `"enabled_modules follows registry order"`: `enable_module!(:backflow, ...)`, so `enabled_modules.map(&:key) == ["backflow"]`
  - `"the model rejects keys outside the registry"`: `assert_not TenantModule.new(tenant_id: @tenant.id, module_key: "nope").valid?`
- [ ] **Step 3: Run** `bin/rails test test/models/tenant_module_test.rb`. Expected: FAIL (`NoMethodError: module_enabled?`).
- [ ] **Step 4: Implement** the models and `Tenant` methods:
  - `module_enabled?` and `enabled_modules` read a memoized `@enabled_module_keys` (the set of `module_key`s from `tenant_modules_dataset`, intersected with `Registry.keys`). Clear the memo in `refresh` and at the end of both bang methods.
  - `enable_module!` / `disable_module!` wrap the row write and the event insert in `db.transaction`, with `enabled_at:` and `created_at:` set to `Time.current`. In `enable_module!`, rescue `Sequel::UniqueConstraintViolation` around the insert using `db.transaction(savepoint: true)`, so a race returns `false` without aborting an outer transaction (tests run inside one).
- [ ] **Step 5: Run** that file, then `bin/rails test` (the full suite, including `schema_test.rb`) and `bin/rubocop`. Expected: all PASS, no offenses.
- [ ] **Step 6: Commit** the migration, `db/structure.sql`, models and test: "Store which modules each tenant has, with an audit trail".

**Open PR 1** against `master` titled "Tenant modules: registry and assignment storage", body `Closes #15`.

---

## Issue 2 (#16) — Module guard, backflow module, generic dashboard (branch `ms-tenant-modules-guard`, based on `ms-tenant-modules-registry`)

### Task 3: `RequiresModule` guard and the backflow module

**Files:**
- Create: `app/controllers/concerns/requires_module.rb`
- Create: `app/controllers/backflow/base_controller.rb`, `app/controllers/backflow/home_controller.rb`
- Create: `app/views/backflow/home/show.html.erb` (moved with `git mv` from `app/views/dashboard/show.html.erb`)
- Modify: `app/controllers/dashboard_controller.rb` (the `SAMPLE` constant and `show` body move out), `config/routes.rb`
- Test: `test/integration/backflow/home_test.rb`, `test/controllers/requires_module_test.rb`

**Interfaces:**
- Consumes: `Tenant#module_enabled?`, `Tenant#enable_module!`, `TenantModules::Registry.find`
- Produces:
  - `RequiresModule` concern with the class method `requires_module(key)`. It raises `ArgumentError, "unknown module: #{key}"` at class-definition time when `Registry.find(key)` is nil. Otherwise it adds `before_action :require_module`, which renders `render_not_found` unless `current_tenant.module_enabled?(key)`.
  - `Backflow::BaseController < ApplicationController`, with `include TenantScoped`, `include RequiresModule`, `requires_module :backflow`, in that order, so login and inactive-tenant checks run first.
  - Route `namespace :backflow do root to: "home#show" end`, giving `/backflow` and `backflow_root_path`.

- [ ] **Step 1: Write the failing tests.**
  - `test/integration/backflow/home_test.rb` (setup: `@tenant = Tenant.create(name: "City of Ruston", slug: "ruston")`, `@staff = create_account(email: "staff@ruston.test", tenant_id: @tenant.id)`):
    - `"anonymous visitor is sent to login"`: `get "/backflow"` redirects to `"/login"`
    - `"a tenant with the module sees the backflow home"`: `@tenant.enable_module!(:backflow, by: nil)`, sign in, `get "/backflow"` gives 200 and `assert_match "Upcoming Inspections", response.body`
    - `"a tenant without the module gets 404"`
    - `"an inactive tenant with the module gets 404"`
    - `"a super admin with no tenant gets 404"`
    - `"impersonating into a tenant with the module reaches it"` and `"...without the module gets 404"`. Use `post "/super-admin/accounts/#{@staff.id}/impersonate"`, as in `test/integration/impersonation_test.rb`.
  - `test/controllers/requires_module_test.rb`: `"an unknown module key raises when declared"`, with `assert_raises(ArgumentError) { Class.new(ApplicationController) { include RequiresModule; requires_module :nope } }`
- [ ] **Step 2: Run** both files. Expected: FAIL (routing error, uninitialized constant).
- [ ] **Step 3: Implement.** Move `SAMPLE` (keeping its "SKETCH DATA … delete once real models land" comment) and the `show` body into `Backflow::HomeController`, and `git mv` the view. In the view, the heading changes from "Welcome back, …" to "Backflow Inspections". Everything else in the view stays as it is. Leave `DashboardController#show` empty for now (Task 4 fills it), and give `app/views/dashboard/show.html.erb` a minimal `<h1>Welcome back</h1>` so the existing dashboard tests still pass in this commit.
- [ ] **Step 4: Run** both files plus `bin/rails test test/integration`. Expected: PASS.
- [ ] **Step 5: Commit**: "Gate module routes and move the dashboard mockup into the backflow module".

### Task 4: Generic core dashboard and module-aware sidebar

**Files:**
- Modify: `app/controllers/dashboard_controller.rb`, `app/views/dashboard/show.html.erb`
- Modify: `app/views/layouts/partials/_app_sidebar.html.erb`
- Test: `test/integration/dashboard_test.rb`

**Interfaces:**
- Consumes: `current_tenant.enabled_modules` and `Definition#home_path`, `#nav_items`, `#name`, `#description`
- Produces: nothing new for later tasks

- [ ] **Step 1: Write the failing tests** in `dashboard_test.rb`. Keep the existing six tests unchanged ("Welcome back" stays in the h1). Add:
  - `"dashboard names the tenant"`: `assert_select "h1", /City of Summit/`
  - `"a tenant with backflow gets a card linking to it"`: enable, `get "/dashboard"`, `assert_select "a[href=?]", "/backflow"`, `assert_match "Backflow Inspections", response.body`
  - `"a tenant with no modules sees the empty state"`: `assert_match "No modules are set up for your organization yet", response.body`
  - `"the core dashboard carries no backflow content"`: with backflow enabled, `assert_no_match "Upcoming Inspections", response.body`
  - `"the sidebar shows Inspections only with the module"`: without the module, `assert_select "nav a[href=?]", "/backflow", count: 0`. With it, `count: 1` inside the sidebar `nav`. Scope the selector so the dashboard card's link isn't counted. Pick a selector that's unambiguous for the markup you write and note it in the test.
  - `"a retired module row does not break the dashboard"`: `TenantModule.dataset.insert(tenant_id: tenant.id, module_key: "retired", enabled_at: Time.current)`, then `get "/dashboard"` gives 200 and the empty-state text
  - `"the sidebar no longer lists placeholder backflow items"`: `assert_no_match ">Appliances<", response.body` for a tenant without modules. Match the label as the partial renders it.
- [ ] **Step 2: Run** `bin/rails test test/integration/dashboard_test.rb`. Expected: the new tests FAIL.
- [ ] **Step 3: Implement.**
  - The dashboard view gets the h1 `Welcome back, <name>`, a line with `current_tenant.name`, then a grid of cards, one per `current_tenant.enabled_modules`. Each card shows the module's name and description and links to `public_send(definition.home_path)`. With none, show the empty-state copy exactly: **"No modules are set up for your organization yet. Contact support to get started."** Use the existing card styling (`rounded-2xl border border-line bg-white`).
  - In the sidebar, the core `nav_items` become Dashboard, Plumbers, and Settings (inert). Append `current_tenant.enabled_modules.flat_map(&:nav_items)`, resolving `path` with `public_send`. Remove the Customers, Appliances, Inspections and Reports placeholders. Update the partial's header comment to describe core items vs module items. Keep the active-state styling and the Platform section exactly as they are.
- [ ] **Step 4: Run** `bin/rails test` and `bin/rubocop`. Expected: all PASS, including `impersonation_test.rb` ("the impersonator sees the app as the target" still GETs `/dashboard`).
- [ ] **Step 5: Commit**: "Make the dashboard and sidebar follow the tenant's modules".

**Open PR 2** with base `ms-tenant-modules-registry`, titled "Tenant modules: guard, backflow module, generic dashboard", body `Closes #16`, noting that it stacks on PR 1.

---

## Issue 3 (#17) — Super admin module controls (branch `ms-tenant-modules-admin`, based on `ms-tenant-modules-guard`)

### Task 5: Enable/disable actions, Modules panel, tenants index column

**Files:**
- Create: `app/controllers/super_admin/tenant_modules_controller.rb`
- Create: `app/views/super_admin/tenants/_modules_panel.html.erb`
- Modify: `config/routes.rb`, `app/views/super_admin/tenants/edit.html.erb`, `app/views/super_admin/tenants/index.html.erb`, `app/controllers/super_admin/tenants_controller.rb` (index only, if it needs to preload)
- Test: `test/integration/super_admin_tenant_modules_test.rb`

**Interfaces:**
- Consumes: `Tenant#enable_module!`, `#disable_module!`, `#module_enabled?`, `#module_enabled_at`, `#enabled_modules`, `TenantModules::Registry.all`, `.find`
- Produces: routes `enable_super_admin_tenant_module_path(tenant, key)` and `disable_super_admin_tenant_module_path(tenant, key)` → `PATCH /super-admin/tenants/:tenant_id/modules/:key/enable|disable`, via the nested `resources :modules, only: [], param: :key, controller: "tenant_modules"` block from the spec.

- [ ] **Step 1: Write the failing tests** (setup: tenant "City of Ruston"/`ruston`, `@boss` super admin, `@admin = create_account(email: "admin@ruston.test", tenant_id: tenant.id)`):
  - `"super admin enables a module"`: `patch "/super-admin/tenants/#{t.id}/modules/backflow/enable"` redirects to `"/super-admin/tenants/#{t.id}/edit"`, `flash[:notice] == "Backflow Inspections enabled for City of Ruston."`, the module is enabled, and the event's `account_id == @boss.id`
  - `"super admin disables a module"`: flash is `"Backflow Inspections disabled for City of Ruston."`
  - `"enabling an enabled module just redirects"`: no second event
  - `"enabling on an inactive tenant is allowed but still locked out"`: after enabling, sign in as `@admin` and `get "/backflow"` gives 404
  - `"a tenant admin cannot toggle modules"`: signed in as `@admin`, the PATCH gives 404 and the module stays off
  - `"unknown module key is 404"`: `.../modules/nope/enable`. Also `.../modules/Backflow/enable` is 404.
  - `"unknown or non-numeric tenant is 404"`: `/super-admin/tenants/999999/modules/backflow/enable` and `/super-admin/tenants/abc/modules/backflow/enable`
  - `"edit page lists every module with its state"`: `get edit`, then `assert_match "Backflow Inspections", body` and an `Enable` button. After enabling, a `Disable` button and `"Enabled since"`.
  - `"disable asks for confirmation"`: `assert_select "form[action=?] [data-turbo-confirm]", "/super-admin/tenants/#{t.id}/modules/backflow/disable"`
  - `"tenants index shows enabled modules"`: after enabling, `get "/super-admin/tenants"` and `assert_match "Backflow Inspections", body`
  - `"a retired module row does not break the super admin pages"`: insert a `"retired"` row, then edit and index both return 200
- [ ] **Step 2: Run** `bin/rails test test/integration/super_admin_tenant_modules_test.rb`. Expected: FAIL (routing error).
- [ ] **Step 3: Implement.**
  - The controller inherits `SuperAdmin::BaseController`. `before_action :set_tenant` uses `Tenant[params[:tenant_id].to_i]` and returns 404 if missing. `before_action :set_definition` uses `Registry.find(params[:key])` and returns 404 if nil. `enable` / `disable` call the bang method with `by: current_account` and redirect to `edit_super_admin_tenant_path(@tenant)` with the notices above.
  - The panel partial is a separate card below the form on `edit.html.erb`, titled "Modules". For each `Registry.all` it shows the name, the description, a status ("Enabled since <%= l(tenant.module_enabled_at(key).to_date, format: :long) %>" or "Off"), and a `button_to` Enable or Disable with `method: :patch`. Disable gets `form: { data: { turbo_confirm: "Turn off #{name} for #{tenant.name}? Their data is kept and returns if you turn it back on." } }`. Copy the button classes from `index.html.erb`'s Activate/Deactivate buttons.
  - The index gets a "Modules" column between Accounts and Status: `tenant.enabled_modules.map(&:name).join(", ")`, or an em dash when there are none. Watch for N+1. The tenants list is small, so one query per row is acceptable for now. Note that in a comment.
- [ ] **Step 4: Run** `bin/rails test`, `bin/rubocop`, `bin/brakeman --no-pager`. Expected: all clean.
- [ ] **Step 5: Manual check.** `bin/dev` on a free port (port 3000 is taken by bitspace-rails: `bin/rails s -p 3001`). Sign in as a super admin, enable Backflow for a tenant, impersonate one of its accounts, and confirm the Inspections nav item and `/backflow` work. Disable it and confirm both disappear.
- [ ] **Step 6: Commit**: "Let the super admin switch modules on and off per tenant".

**Open PR 3** with base `ms-tenant-modules-guard`, titled "Tenant modules: super admin controls", body `Closes #17`.
