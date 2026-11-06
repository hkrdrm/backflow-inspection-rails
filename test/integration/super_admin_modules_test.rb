require "test_helper"

# Platform → Modules: a read-only catalog of every module that exists.
class SuperAdminModulesTest < ActionDispatch::IntegrationTest
  setup do
    @boss = create_account(email: "boss@example.com", super_admin: true)
  end

  test "lists every module with its pages" do
    sign_in @boss

    get "/super-admin/modules"

    assert_response :success
    assert_select "[data-module=backflow] h2", "Backflow Inspections"
    assert_select "[data-module=backflow]", /Overview/
    assert_select "[data-module=backflow]", /Testers/
  end

  test "shows which tenants have each module, linking to them" do
    ruston = Tenant.create(name: "City of Ruston", slug: "ruston")
    ruston.enable_module!(:backflow, by: nil)
    Tenant.create(name: "Terrebonne Parish", slug: "terrebonne")
    sign_in @boss

    get "/super-admin/modules"

    assert_select "[data-module=backflow] a[href=?]", "/super-admin/tenants/#{ruston.id}/edit", text: "City of Ruston"
    assert_select "[data-module=backflow]", { text: /Terrebonne Parish/, count: 0 }
    assert_select "[data-module=backflow]", /1 tenant\b/
  end

  test "explains that new modules are built in code" do
    sign_in @boss

    get "/super-admin/modules"

    assert_match "app/modules/tenant_modules/registry.rb", response.body
  end

  test "a retired module row does not break the page" do
    tenant = Tenant.create(name: "City of Ruston", slug: "ruston")
    TenantModule.dataset.insert(tenant_id: tenant.id, module_key: "retired", enabled_at: Time.current)
    sign_in @boss

    get "/super-admin/modules"

    assert_response :success
  end

  test "is hidden from everyone but super admins" do
    tenant = Tenant.create(name: "City of Ruston", slug: "ruston")
    sign_in create_account(email: "admin@ruston.test", tenant_id: tenant.id)

    get "/super-admin/modules"

    assert_response :not_found
  end

  test "the Platform section links to Modules" do
    sign_in @boss

    get "/super-admin/tenants"

    assert_select "aside a[href=?]", "/super-admin/modules", text: /Modules/
  end

  # --- Platform-wide status ---------------------------------------------------

  test "each module shows its platform status" do
    sign_in @boss

    get "/super-admin/modules"

    assert_select "[data-module=backflow] [data-status]", "Active"
  end

  test "a super admin changes a module's status, and it is logged" do
    sign_in @boss

    patch "/super-admin/modules/backflow", params: { status: "planned" }

    assert_redirected_to "/super-admin/modules"
    assert_equal "Backflow Inspections is now Planned.", flash[:notice]
    assert_equal "planned", PlatformModule.status_for(:backflow)
    assert_equal [ "active", "planned", @boss.id ],
                 PlatformModuleEvent.order(:id).last.values.values_at(:from_status, :to_status, :account_id)
  end

  test "the status buttons offer the other statuses, and Disable asks first" do
    sign_in @boss

    get "/super-admin/modules"

    assert_select "[data-module=backflow] form[action=?] button", "/super-admin/modules/backflow", text: "Disable"
    assert_select "[data-module=backflow] form[action=?] button", "/super-admin/modules/backflow", text: "Mark planned"
    assert_select "[data-module=backflow] form[action='/super-admin/modules/backflow'] button",
                  { text: "Activate", count: 0 }, "already active"
    assert_select "[data-module=backflow] form[data-turbo-confirm]", 1
  end

  test "an unknown status or module is rejected" do
    sign_in @boss

    patch "/super-admin/modules/backflow", params: { status: "retired" }
    assert_response :unprocessable_entity
    assert_equal "active", PlatformModule.status_for(:backflow)

    patch "/super-admin/modules/nope", params: { status: "active" }
    assert_response :not_found
  end

  test "only super admins can change a module's status" do
    tenant = Tenant.create(name: "City of Ruston", slug: "ruston")
    sign_in create_account(email: "admin@ruston.test", tenant_id: tenant.id)

    patch "/super-admin/modules/backflow", params: { status: "disabled" }

    assert_response :not_found
    assert_equal "active", PlatformModule.status_for(:backflow)
  end
end
