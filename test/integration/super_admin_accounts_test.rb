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

  # The behavioral assertions above can't independently catch a permit-list
  # regression on :status: `create` unconditionally overrides
  # @account.status = :verified after mass-assignment, so that assertion would
  # pass even if :status were mistakenly permitted. Assert on the permitted
  # set directly so a future widening is caught regardless of the override.
  test "never permits super_admin or status for mass assignment" do
    refute_includes SuperAdmin::AccountsController::PERMITTED_PARAMS, :status
    refute_includes SuperAdmin::AccountsController::PERMITTED_PARAMS, :super_admin
  end

  test "renders the edit form for an existing account" do
    account = create_account(email: "edit@acme.test", tenant_id: @tenant.id)
    sign_in @boss

    get "/super-admin/accounts/#{account.id}/edit"

    assert_response :success
  end

  test "returns 404 for an account that does not exist" do
    sign_in @boss

    get "/super-admin/accounts/999999/edit"

    assert_response :not_found
  end

  test "a non-numeric account id is not found rather than an error" do
    sign_in @boss

    get "/super-admin/accounts/abc/edit"

    assert_response :not_found
  end

  test "updates tenant and role" do
    account = create_account(email: "edit@acme.test")
    sign_in @boss

    patch "/super-admin/accounts/#{account.id}", params: {
      account: { email: "edit@acme.test", tenant_id: @tenant.id, role: "plumber" }
    }

    assert_redirected_to "/super-admin/accounts"
    assert_equal @tenant.id, account.reload.tenant_id
    assert_equal "plumber", account.role
  end

  test "a blank password leaves the existing hash untouched" do
    account = create_account(email: "edit@acme.test", tenant_id: @tenant.id)
    before = account.password_hash
    sign_in @boss

    patch "/super-admin/accounts/#{account.id}", params: {
      account: { email: "edit@acme.test", tenant_id: @tenant.id, role: "admin", password: "" }
    }

    assert_equal before, account.reload.password_hash
  end

  test "a supplied password replaces the old one" do
    account = create_account(email: "edit@acme.test", tenant_id: @tenant.id)
    before = account.password_hash
    sign_in @boss

    patch "/super-admin/accounts/#{account.id}", params: {
      account: { email: "edit@acme.test", tenant_id: @tenant.id, role: "admin",
                 password: "a whole new password" }
    }

    assert_not_equal before, account.reload.password_hash

    post "/logout"
    post "/login", params: { "email" => "edit@acme.test", "password" => "a whole new password" }
    get "/super-admin/accounts"
    assert_response :not_found
  end

  test "a too-short password on update changes nothing" do
    account = create_account(email: "edit@acme.test", tenant_id: @tenant.id)
    before = account.password_hash
    sign_in @boss

    patch "/super-admin/accounts/#{account.id}", params: {
      account: { email: "edit@acme.test", tenant_id: @tenant.id, role: "admin", password: "sevench" }
    }

    assert_response 422
    assert_equal before, account.reload.password_hash
  end

  test "ignores super_admin and status injected into update params" do
    account = create_account(email: "edit@acme.test", tenant_id: @tenant.id)
    sign_in @boss

    patch "/super-admin/accounts/#{account.id}", params: {
      account: { email: "edit@acme.test", tenant_id: @tenant.id, role: "admin",
                 super_admin: true, status: 3 }
    }

    assert_equal false, account.reload.super_admin?
    assert_equal :verified, account.status
  end

  test "closing an account keeps the row and blocks login" do
    account = create_account(email: "gone@acme.test", tenant_id: @tenant.id)
    sign_in @boss

    patch "/super-admin/accounts/#{account.id}/close"

    assert_equal :closed, account.reload.status
    assert_equal 1, Account.where(id: account.id).count

    post "/logout"
    post "/login", params: { "email" => "gone@acme.test", "password" => TEST_PASSWORD }

    # Still anonymous, so a protected page redirects to login rather than 404ing.
    get "/super-admin/accounts"
    assert_redirected_to "/login"
  end

  test "reopening restores a closed account" do
    account = create_account(email: "back@acme.test", tenant_id: @tenant.id)
    account.update(status: :closed)
    sign_in @boss

    patch "/super-admin/accounts/#{account.id}/reopen"

    assert_equal :verified, account.reload.status
  end

  test "reopening is refused when the email is taken by an open account" do
    closed = create_account(email: "dup@acme.test", tenant_id: @tenant.id)
    closed.update(status: :closed)
    create_account(email: "dup@acme.test", tenant_id: @tenant.id)
    sign_in @boss

    patch "/super-admin/accounts/#{closed.id}/reopen"

    assert_redirected_to "/super-admin/accounts"
    assert_equal :closed, closed.reload.status
  end

  test "closing your own account is refused" do
    sign_in @boss

    patch "/super-admin/accounts/#{@boss.id}/close"

    assert_redirected_to "/super-admin/accounts"
    assert_equal :verified, @boss.reload.status
  end

  test "grants and revokes the super admin flag" do
    account = create_account(email: "deputy@example.com")
    sign_in @boss

    patch "/super-admin/accounts/#{account.id}/grant_super_admin"
    assert_equal true, account.reload.super_admin?

    patch "/super-admin/accounts/#{account.id}/revoke_super_admin"
    assert_equal false, account.reload.super_admin?
  end

  test "revoking your own super admin flag is refused" do
    sign_in @boss

    patch "/super-admin/accounts/#{@boss.id}/revoke_super_admin"

    assert_redirected_to "/super-admin/accounts"
    assert_equal true, @boss.reload.super_admin?
  end
end
