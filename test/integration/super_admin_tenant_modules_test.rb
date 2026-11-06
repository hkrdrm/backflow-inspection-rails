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

  test "edit page lists every module with its state" do
    sign_in @boss

    get "/super-admin/tenants/#{@tenant.id}/edit"
    assert_match "Backflow Inspections", response.body
    assert_select "form[action=?] button", "/super-admin/tenants/#{@tenant.id}/modules/backflow/enable", text: "Enable"

    @tenant.enable_module!(:backflow, by: nil)
    get "/super-admin/tenants/#{@tenant.id}/edit"
    assert_select "form[action=?] button", "/super-admin/tenants/#{@tenant.id}/modules/backflow/disable", text: "Disable"
    assert_match "Enabled since", response.body
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
end
