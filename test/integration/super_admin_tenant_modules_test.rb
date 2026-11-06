require "test_helper"

class SuperAdminTenantModulesTest < ActionDispatch::IntegrationTest
  setup do
    @tenant = Tenant.create(name: "City of Ruston", slug: "ruston")
    @boss = create_account(email: "boss@example.com", super_admin: true)
    @admin = create_account(email: "admin@ruston.test", tenant_id: @tenant.id)
  end

  def toggle(action, key: "backflow", tenant_id: @tenant.id)
    patch "/super-admin/tenants/#{tenant_id}/modules/#{key}/#{action}"
  end

  def events
    TenantModuleEvent.where(tenant_id: @tenant.id).order(:id).all
  end

  test "super admin enables a module" do
    sign_in @boss

    toggle :enable

    assert_redirected_to "/super-admin/tenants/#{@tenant.id}/edit"
    assert_equal "Backflow Inspections enabled for City of Ruston.", flash[:notice]
    assert @tenant.refresh.module_enabled?(:backflow)
    assert_equal @boss.id, events.last.account_id
  end

  test "super admin disables a module" do
    @tenant.enable_module!(:backflow, by: nil)
    sign_in @boss

    toggle :disable

    assert_redirected_to "/super-admin/tenants/#{@tenant.id}/edit"
    assert_equal "Backflow Inspections disabled for City of Ruston.", flash[:notice]
    assert_not @tenant.refresh.module_enabled?(:backflow)
    assert_equal [ "enabled", "disabled" ], events.map(&:action)
    assert_equal @boss.id, events.last.account_id
  end

  test "enabling an enabled module just redirects" do
    @tenant.enable_module!(:backflow, by: nil)
    sign_in @boss

    toggle :enable

    assert_redirected_to "/super-admin/tenants/#{@tenant.id}/edit"
    assert_equal 1, events.size
  end

  test "enabling on an inactive tenant is allowed but still locked out" do
    @tenant.update(active: false)
    sign_in @boss

    toggle :enable
    assert @tenant.refresh.module_enabled?(:backflow)

    reset!
    sign_in @admin
    get "/backflow"
    assert_response :not_found
  end

  test "a tenant admin cannot toggle modules" do
    sign_in @admin

    toggle :enable

    assert_response :not_found
    assert_not @tenant.refresh.module_enabled?(:backflow)
  end

  test "unknown module key is 404" do
    sign_in @boss

    toggle :enable, key: "nope"
    assert_response :not_found

    toggle :enable, key: "Backflow"
    assert_response :not_found
    assert_empty events
  end

  test "unknown or non-numeric tenant is 404" do
    sign_in @boss

    toggle :enable, tenant_id: 999_999
    assert_response :not_found

    toggle :enable, tenant_id: "abc"
    assert_response :not_found
  end

  test "the tenant page lists its modules with Remove" do
    @tenant.enable_module!(:backflow, by: nil)
    sign_in @boss

    get "/super-admin/tenants/#{@tenant.id}/edit"

    assert_select "[data-tenant-modules] li", text: /Backflow Inspections/
    assert_match "Enabled since", response.body
    assert_select "form[action=?] button", "/super-admin/tenants/#{@tenant.id}/modules/backflow/disable", text: "Remove"
  end

  test "the tenant page offers only modules the tenant does not have" do
    sign_in @boss

    get "/super-admin/tenants/#{@tenant.id}/edit"
    assert_select "[data-tenant-modules] li", count: 0
    assert_select "[data-add-module] select option[value=?]", "backflow", text: "Backflow Inspections"

    @tenant.enable_module!(:backflow, by: nil)
    get "/super-admin/tenants/#{@tenant.id}/edit"
    assert_select "[data-add-module]", count: 0, message: "nothing left to add, so no Add form"
  end

  test "adding a module from the tenant page enables it and logs who did it" do
    sign_in @boss

    post "/super-admin/tenants/#{@tenant.id}/modules", params: { key: "backflow" }

    assert_redirected_to "/super-admin/tenants/#{@tenant.id}/edit"
    assert_equal "Backflow Inspections added to City of Ruston.", flash[:notice]
    assert @tenant.refresh.module_enabled?(:backflow)
    assert_equal [ [ "enabled", @boss.id ] ], events.map { |e| [ e.action, e.account_id ] }
  end

  test "adding an unknown or blank module is 404" do
    sign_in @boss

    post "/super-admin/tenants/#{@tenant.id}/modules", params: { key: "nope" }
    assert_response :not_found

    post "/super-admin/tenants/#{@tenant.id}/modules", params: { key: "" }
    assert_response :not_found
    assert_empty events
  end

  test "a tenant admin cannot add modules" do
    sign_in @admin

    post "/super-admin/tenants/#{@tenant.id}/modules", params: { key: "backflow" }

    assert_response :not_found
    assert_not @tenant.refresh.module_enabled?(:backflow)
  end

  test "disable asks for confirmation" do
    @tenant.enable_module!(:backflow, by: nil)
    sign_in @boss

    get "/super-admin/tenants/#{@tenant.id}/edit"

    assert_select "form[action=?][data-turbo-confirm]", "/super-admin/tenants/#{@tenant.id}/modules/backflow/disable"
  end

  test "tenants index shows enabled modules" do
    @tenant.enable_module!(:backflow, by: nil)
    sign_in @boss

    get "/super-admin/tenants"

    assert_select "td", text: "Backflow Inspections"
  end

  test "a retired module row does not break the super admin pages" do
    TenantModule.dataset.insert(tenant_id: @tenant.id, module_key: "retired", enabled_at: Time.current)
    sign_in @boss

    get "/super-admin/tenants/#{@tenant.id}/edit"
    assert_response :success

    get "/super-admin/tenants"
    assert_response :success
  end

  # --- Platform-wide status ---------------------------------------------------

  test "the Add module dropdown offers only active modules" do
    PlatformModule.set_status!(:backflow, "planned", by: nil)
    sign_in @boss

    get "/super-admin/tenants/#{@tenant.id}/edit"

    assert_select "[data-add-module]", count: 0
  end

  test "adding a module that isn't active is refused" do
    PlatformModule.set_status!(:backflow, "disabled", by: nil)
    sign_in @boss

    post "/super-admin/tenants/#{@tenant.id}/modules", params: { key: "backflow" }

    assert_redirected_to "/super-admin/tenants/#{@tenant.id}/edit"
    assert_equal "Backflow Inspections is Disabled platform-wide, so it can't be added.", flash[:alert]
    assert_not @tenant.refresh.module_assigned?(:backflow)
  end

  test "an assigned module that is off platform-wide says so on the tenant page" do
    @tenant.enable_module!(:backflow, by: nil)
    PlatformModule.set_status!(:backflow, "disabled", by: nil)
    sign_in @boss

    get "/super-admin/tenants/#{@tenant.id}/edit"

    assert_select "[data-tenant-modules] li", /Backflow Inspections/
    assert_select "[data-tenant-modules] li", /Disabled platform-wide/
  end
end
