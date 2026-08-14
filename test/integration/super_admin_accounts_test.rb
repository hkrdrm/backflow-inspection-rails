require "test_helper"

class SuperAdminAccountsTest < ActionDispatch::IntegrationTest
  setup do
    @tenant = Tenant.create(name: "Acme Water", slug: "acme")
    @boss = create_account(email: "boss@example.com", super_admin: true)
  end

  test "anonymous visitor is sent to login" do
    get "/super-admin/accounts"

    assert_redirected_to "/login"
  end

  test "logged in account without the flag is not told the area exists" do
    sign_in create_account(email: "regular@example.com")

    get "/super-admin/accounts"

    assert_response :not_found
  end

  test "lists accounts from every tenant" do
    create_account(email: "one@acme.test", tenant_id: @tenant.id)
    create_account(email: "two@elsewhere.test")
    sign_in @boss

    get "/super-admin/accounts"

    assert_response :success
    assert_match "one@acme.test", response.body
    assert_match "two@elsewhere.test", response.body
    assert_match "Acme Water", response.body
  end

  test "filters by tenant" do
    create_account(email: "one@acme.test", tenant_id: @tenant.id)
    create_account(email: "two@elsewhere.test")
    sign_in @boss

    get "/super-admin/accounts", params: { tenant_id: @tenant.id }

    assert_match "one@acme.test", response.body
    assert_no_match "two@elsewhere.test", response.body
  end

  test "searches by email regardless of case" do
    create_account(email: "one@acme.test", tenant_id: @tenant.id)
    create_account(email: "two@elsewhere.test")
    sign_in @boss

    get "/super-admin/accounts", params: { q: "ACME" }

    assert_match "one@acme.test", response.body
    assert_no_match "two@elsewhere.test", response.body
  end

  test "treats a LIKE wildcard in the search as a literal character" do
    create_account(email: "one@acme.test", tenant_id: @tenant.id)
    sign_in @boss

    get "/super-admin/accounts", params: { q: "%" }

    assert_no_match "one@acme.test", response.body
  end
end
