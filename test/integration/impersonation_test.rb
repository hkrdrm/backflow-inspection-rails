require "test_helper"

class ImpersonationTest < ActionDispatch::IntegrationTest
  setup do
    @tenant = Tenant.create(name: "Acme Water", slug: "acme")
    @boss = create_account(email: "boss@example.com", super_admin: true)
    @target = create_account(email: "target@acme.test", tenant_id: @tenant.id)
  end

  def impersonate(account)
    post "/super-admin/accounts/#{account.id}/impersonate"
  end

  test "starting an impersonation records a live session" do
    sign_in @boss

    assert_difference -> { ImpersonationSession.count }, 1 do
      impersonate(@target)
    end

    session = ImpersonationSession.order(:id).last
    assert_equal @boss.id, session.impersonator_account_id
    assert_equal @target.id, session.impersonated_account_id
    assert_equal @tenant.id, session.tenant_id
    assert session.live?
  end

  test "the impersonator sees the app as the target" do
    sign_in @boss
    impersonate(@target)

    get "/dashboard"

    assert_response :success
    assert_match "target@acme.test", response.body
    assert_match "Stop impersonating", response.body
  end

  test "the back office is hidden while impersonating" do
    sign_in @boss
    impersonate(@target)

    get "/super-admin/accounts"

    assert_response :not_found
  end

  test "stopping restores the operator and ends the session" do
    sign_in @boss
    impersonate(@target)

    delete "/impersonation"

    assert_redirected_to "/super-admin/accounts"
    assert_not ImpersonationSession.order(:id).last.live?

    get "/super-admin/accounts"
    assert_response :success
    assert_no_match "Stop impersonating", response.body
  end

  test "impersonating yourself is refused" do
    sign_in @boss

    assert_no_difference -> { ImpersonationSession.count } do
      impersonate(@boss)
    end

    assert_redirected_to "/super-admin/accounts"
  end

  test "impersonating another super admin is refused" do
    peer = create_account(email: "peer@example.com", super_admin: true)
    sign_in @boss

    assert_no_difference -> { ImpersonationSession.count } do
      impersonate(peer)
    end

    assert_redirected_to "/super-admin/accounts"
  end

  test "an ordinary account cannot start an impersonation" do
    sign_in create_account(email: "regular@acme.test", tenant_id: @tenant.id)

    assert_no_difference -> { ImpersonationSession.count } do
      impersonate(@target)
    end

    assert_response :not_found
  end

  test "an ordinary account cannot stop one it never started" do
    sign_in create_account(email: "regular@acme.test", tenant_id: @tenant.id)

    delete "/impersonation"

    assert_response :not_found
  end

  test "impersonating an account with no active tenant lands somewhere with a way back" do
    stranded = create_account(email: "stranded@example.com")
    sign_in @boss

    impersonate(stranded)

    assert_redirected_to "/"
    follow_redirect!
    assert_response :success
    assert_match "Stop impersonating", response.body
  end
end
