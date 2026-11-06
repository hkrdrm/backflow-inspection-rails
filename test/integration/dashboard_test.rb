require "test_helper"

class DashboardTest < ActionDispatch::IntegrationTest
  test "anonymous visitor is sent to login" do
    get "/dashboard"

    assert_redirected_to "/login"
  end

  test "signed in account sees the dashboard" do
    tenant = Tenant.create(name: "City of Summit", slug: "summit")
    sign_in create_account(email: "owner@example.com", tenant_id: tenant.id)

    get "/dashboard"

    assert_response :success
    assert_select "h1", /Welcome back/
  end

  test "sidebar hides the platform section from ordinary accounts" do
    tenant = Tenant.create(name: "City of Summit", slug: "summit")
    sign_in create_account(email: "owner@example.com", tenant_id: tenant.id)

    get "/dashboard"

    assert_select "a[href=?]", "/super-admin", count: 0
  end

  test "sidebar shows the platform section to super admins" do
    sign_in create_account(email: "boss@example.com", super_admin: true)

    get "/super-admin/tenants"

    assert_select "a[href=?]", "/super-admin", minimum: 1
  end

  test "staff of a deactivated tenant are locked out of the dashboard" do
    tenant = Tenant.create(name: "City of Summit", slug: "summit")
    tenant.update(active: false)
    sign_in create_account(email: "staff@example.com", tenant_id: tenant.id)

    get "/dashboard"

    assert_response :not_found
  end

  test "a super admin has no tenant dashboard" do
    sign_in create_account(email: "boss@example.com", super_admin: true)

    get "/dashboard"

    assert_response :not_found
  end

  # --- Modules --------------------------------------------------------------

  def sign_in_to_summit
    tenant = Tenant.create(name: "City of Summit", slug: "summit")
    sign_in create_account(email: "owner@example.com", tenant_id: tenant.id)
    tenant
  end

  test "dashboard greets the person and names the tenant" do
    sign_in_to_summit

    get "/dashboard"

    assert_select "h1", /Welcome back, Owner\./
    assert_select "main p", /City of Summit/
  end

  test "module links sit above Settings" do
    sign_in_to_summit.enable_module!(:backflow, by: nil)

    get "/dashboard"

    labels = css_select("aside nav li").map { |li| li.text.strip }
    assert_operator labels.index("Backflow Inspections"), :<, labels.index("Settings")
  end

  test "a tenant with backflow gets a card linking to it" do
    sign_in_to_summit.enable_module!(:backflow, by: nil)

    get "/dashboard"

    assert_select "main a[href=?]", "/backflow"
    assert_match "Backflow Inspections", response.body
  end

  test "a tenant with no modules sees the empty state" do
    sign_in_to_summit

    get "/dashboard"

    assert_match "No modules are set up for your organization yet", response.body
  end

  test "the core dashboard carries no backflow content" do
    sign_in_to_summit.enable_module!(:backflow, by: nil)

    get "/dashboard"

    assert_no_match "Upcoming Inspections", response.body
  end

  # Scoped to the sidebar's <aside> so the dashboard card's own link to
  # /backflow is not counted.
  test "the sidebar links to a module only when the tenant has it" do
    tenant = sign_in_to_summit

    get "/dashboard"
    assert_select "aside a[href=?]", "/backflow", count: 0

    tenant.enable_module!(:backflow, by: nil)
    get "/dashboard"
    assert_select "aside a[href=?]", "/backflow", text: /Backflow Inspections/, count: 1
  end

  test "the sidebar lists Dashboard, then modules, then Settings" do
    sign_in_to_summit.enable_module!(:backflow, by: nil)

    get "/dashboard"

    labels = css_select("aside nav ul li").map { |li| li.text.strip }.reject(&:empty?)
    assert_equal [ "Dashboard", "Backflow Inspections", "Settings" ], labels
  end

  # Module pages (Testers, etc.) moved inside their module.
  test "the sidebar no longer has a Plumbers link" do
    sign_in_to_summit.enable_module!(:backflow, by: nil)

    get "/dashboard"

    assert_select "aside", text: /Plumbers/, count: 0
  end

  test "a retired module row does not break the dashboard" do
    tenant = sign_in_to_summit
    TenantModule.dataset.insert(tenant_id: tenant.id, module_key: "retired", enabled_at: Time.current)

    get "/dashboard"

    assert_response :success
    assert_match "No modules are set up for your organization yet", response.body
  end

  test "the sidebar no longer lists placeholder backflow items" do
    sign_in_to_summit

    get "/dashboard"

    %w[Customers Appliances Inspections Reports].each do |label|
      assert_select "aside", text: /#{label}/, count: 0
    end
  end
end
