require "test_helper"

class SuperAdminAccessTest < ActionDispatch::IntegrationTest
  test "anonymous visitor is sent to login" do
    get "/super-admin/tenants"

    assert_redirected_to "/login"
  end

  test "logged in account without the flag is not told the area exists" do
    sign_in create_account(email: "regular@example.com")

    get "/super-admin/tenants"

    assert_response :not_found
  end

  test "nav hides the super admin link from ordinary accounts" do
    sign_in create_account(email: "regular@example.com")

    get "/"

    assert_select "a[href=?]", "/super-admin", count: 0
  end

  test "nav shows the super admin link to super admins" do
    sign_in create_account(email: "boss@example.com", super_admin: true)

    get "/"

    # Rendered once for the desktop nav and once for the mobile menu.
    assert_select "a[href=?]", "/super-admin", minimum: 1
  end

  test "super admin reaches the dashboard" do
    sign_in create_account(email: "boss@example.com", super_admin: true)

    get "/super-admin/tenants"

    assert_response :success
  end

  test "super admin reaches the back-office with no tenant" do
    account = create_account(email: "boss@example.com", super_admin: true)
    assert_nil account.tenant_id

    sign_in account
    get "/super-admin/tenants"

    assert_response :success
  end
end
