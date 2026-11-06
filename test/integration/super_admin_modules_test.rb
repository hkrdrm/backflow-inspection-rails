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
end
