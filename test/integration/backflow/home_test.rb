require "test_helper"

class BackflowHomeTest < ActionDispatch::IntegrationTest
  setup do
    @tenant = Tenant.create(name: "City of Ruston", slug: "ruston")
    @staff = create_account(email: "staff@ruston.test", tenant_id: @tenant.id)
  end

  test "anonymous visitor is sent to login" do
    get "/backflow"

    assert_redirected_to "/login"
  end

  test "a tenant with the module sees the backflow home" do
    @tenant.enable_module!(:backflow, by: nil)
    sign_in @staff

    get "/backflow"

    assert_response :success
    assert_match "Upcoming Inspections", response.body
  end

  test "a tenant without the module gets 404" do
    sign_in @staff

    get "/backflow"

    assert_response :not_found
  end

  test "an inactive tenant with the module gets 404" do
    @tenant.enable_module!(:backflow, by: nil)
    @tenant.update(active: false)
    sign_in @staff

    get "/backflow"

    assert_response :not_found
  end

  test "a super admin with no tenant gets 404" do
    sign_in create_account(email: "boss@example.com", super_admin: true)

    get "/backflow"

    assert_response :not_found
  end

  test "impersonating into a tenant with the module reaches it" do
    @tenant.enable_module!(:backflow, by: nil)
    sign_in create_account(email: "boss@example.com", super_admin: true)
    post "/super-admin/accounts/#{@staff.id}/impersonate"

    get "/backflow"

    assert_response :success
  end

  test "impersonating into a tenant without the module gets 404" do
    sign_in create_account(email: "boss@example.com", super_admin: true)
    post "/super-admin/accounts/#{@staff.id}/impersonate"

    get "/backflow"

    assert_response :not_found
  end

  test "a module disabled platform-wide is 404 even for tenants who have it" do
    @tenant.enable_module!(:backflow, by: nil)
    PlatformModule.set_status!(:backflow, "disabled", by: nil)
    sign_in @staff

    get "/backflow"

    assert_response :not_found
  end
end
