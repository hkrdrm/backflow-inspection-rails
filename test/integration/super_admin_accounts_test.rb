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

  test "renders the new account form" do
    sign_in @boss

    get "/super-admin/accounts/new"

    assert_response :success
  end

  test "creates an account that can log in with the typed password" do
    sign_in @boss

    assert_difference -> { Account.count }, 1 do
      post "/super-admin/accounts", params: {
        account: {
          email: "new@acme.test", tenant_id: @tenant.id, role: "plumber",
          password: "correct horse battery"
        }
      }
    end

    assert_redirected_to "/super-admin/accounts"
    created = Account.first(email: "new@acme.test")
    assert_equal :verified, created.status
    assert_equal "plumber", created.role
    assert_equal @tenant.id, created.tenant_id

    post "/logout"
    post "/login", params: { "email" => "new@acme.test", "password" => "correct horse battery" }

    # Logged in as an ordinary account: the panel 404s rather than redirecting
    # to login, which is what an anonymous request would get.
    get "/super-admin/accounts"
    assert_response :not_found
  end

  test "rejects a password shorter than eight characters" do
    sign_in @boss

    assert_no_difference -> { Account.count } do
      post "/super-admin/accounts", params: {
        account: { email: "short@acme.test", role: "admin", password: "sevench" }
      }
    end

    assert_response 422
  end

  test "rejects an email already used by an open account" do
    create_account(email: "taken@acme.test", tenant_id: @tenant.id)
    sign_in @boss

    assert_no_difference -> { Account.count } do
      post "/super-admin/accounts", params: {
        account: { email: "taken@acme.test", role: "admin", password: "correct horse battery" }
      }
    end

    assert_response 422
  end

  test "ignores super_admin and status injected into create params" do
    sign_in @boss

    post "/super-admin/accounts", params: {
      account: {
        email: "sneaky@acme.test", role: "admin", password: "correct horse battery",
        super_admin: true, status: 3
      }
    }

    created = Account.first(email: "sneaky@acme.test")
    assert_equal false, created.super_admin?
    assert_equal :verified, created.status
  end
end
