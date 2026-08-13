require "test_helper"

class DashboardTest < ActionDispatch::IntegrationTest
  test "anonymous visitor is sent to login" do
    get "/dashboard"

    assert_redirected_to "/login"
  end

  test "signed in account sees the dashboard" do
    sign_in create_account(email: "owner@example.com")

    get "/dashboard"

    assert_response :success
    assert_select "h1", /Welcome back/
  end

  test "sidebar hides the platform section from ordinary accounts" do
    sign_in create_account(email: "owner@example.com")

    get "/dashboard"

    assert_select "a[href=?]", "/super-admin", count: 0
  end

  test "sidebar shows the platform section to super admins" do
    sign_in create_account(email: "boss@example.com", super_admin: true)

    get "/dashboard"

    assert_select "a[href=?]", "/super-admin", minimum: 1
  end
end
