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
    # The message, not just the redirect: refusing a super admin lands in the
    # same place, so only the alert distinguishes this guard from that one.
    assert_equal "You cannot impersonate yourself.", flash[:alert]
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

  # Granting the impersonated account super_admin makes the panel reachable
  # again mid-impersonation, which is the only way to reach this action twice.
  # Without the guard the second row would name the target as the impersonator
  # and the first row would be left live forever.
  test "a second impersonation cannot be started from inside one" do
    other = create_account(email: "other@acme.test", tenant_id: @tenant.id)
    sign_in @boss
    impersonate(@target)
    @target.update(super_admin: true)

    assert_no_difference -> { ImpersonationSession.count } do
      impersonate(other)
    end

    assert_redirected_to "/super-admin/accounts"
    assert_equal "Stop the current impersonation first.", flash[:alert]
  end

  # The exit must not depend on a flag another operator can revoke while the
  # impersonation is in flight, or the banner's only button dies.
  test "an operator whose super admin access was revoked mid-impersonation can still stop" do
    sign_in @boss
    impersonate(@target)
    @boss.update(super_admin: false)

    delete "/impersonation"

    assert_redirected_to "/super-admin/accounts"
    assert_not ImpersonationSession.order(:id).last.live?
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

  test "a write made while impersonating is recorded" do
    sign_in @boss
    impersonate(@target)

    assert_difference -> { ImpersonationEvent.count }, 1 do
      post "/plumbers", params: {
        plumber: { name: "Pat Pike", cert_number: "CERT-1" }
      }
    end

    event = ImpersonationEvent.order(:id).last
    assert_equal ImpersonationSession.order(:id).last.id, event.impersonation_session_id
    assert_equal "POST", event.request_method
    assert_equal "/plumbers", event.path
    assert_equal "plumbers#create", event.controller_action
  end

  test "a rejected write is still recorded" do
    sign_in @boss
    impersonate(@target)

    assert_difference -> { ImpersonationEvent.count }, 1 do
      post "/plumbers", params: { plumber: { name: "", cert_number: "" } }
    end
  end

  test "reads are not recorded" do
    sign_in @boss
    impersonate(@target)

    assert_no_difference -> { ImpersonationEvent.count } do
      get "/plumbers"
    end
  end

  test "starting an impersonation is not itself recorded as the target's write" do
    sign_in @boss

    assert_no_difference -> { ImpersonationEvent.count } do
      impersonate(@target)
    end
  end

  test "writes made outside an impersonation are not recorded" do
    sign_in @boss

    assert_no_difference -> { ImpersonationEvent.count } do
      post "/super-admin/tenants", params: { tenant: { name: "Other", slug: "other" } }
    end
  end

  # Nothing in this app wraps an action in a transaction — Sequel is not
  # Active Record and there is no per-request rollback — so a write that
  # commits before a later line raises is a real, permanent write. No real
  # action can stage that on demand, so the audit hole needs a controller of
  # its own to reproduce.
  class RaisingWriteController < ApplicationController
    def create
      Plumber.create(
        tenant_id: current_account.tenant_id,
        name: "Committed before the raise",
        cert_number: "CERT-BOOM"
      )

      raise "the action blew up after the write landed"
    end
  end

  # `with_routing` is the obvious tool here and the wrong one: it swaps in a
  # fresh integration session, dropping the login and impersonation cookies the
  # test is built on. Appending to the real route set keeps the session.
  def with_throwaway_route(path, to:)
    Rails.application.routes.disable_clear_and_finalize = true
    Rails.application.routes.draw { post path => to }

    yield
  ensure
    Rails.application.routes.disable_clear_and_finalize = false
    Rails.application.reload_routes!
  end

  def with_raising_write_route(&block)
    with_throwaway_route("/raising-write", to: "impersonation_test/raising_write#create", &block)
  end

  def with_halting_write_route(&block)
    with_throwaway_route("/halting-write", to: "impersonation_test/halting_write#create", &block)
  end

  test "a write is recorded even when the action raises after persisting it" do
    sign_in @boss
    impersonate(@target)

    with_raising_write_route do
      assert_difference -> { ImpersonationEvent.count }, 1 do
        assert_raises(RuntimeError) { post "/raising-write" }
      end
    end

    assert Plumber.first(cert_number: "CERT-BOOM"), "the write should have committed"

    event = ImpersonationEvent.order(:id).last
    assert_equal ImpersonationSession.order(:id).last.id, event.impersonation_session_id
    assert_equal "POST", event.request_method
    assert_equal "/raising-write", event.path
    assert_equal "impersonation_test/raising_write#create", event.controller_action
  end

  # A filter registered after the concern — every authorization check in this
  # app is one — halts the chain by rendering, so the action never runs. The
  # around callback has already started by then, so its ensure still fires and
  # the attempt is recorded. That is the intended reading: a refused write is
  # an attempted write, and an audit trail exists to show attempts.
  class HaltingWriteController < ApplicationController
    before_action :refuse

    def create
      raise "the halted chain should never reach the action"
    end

    private

    def refuse
      render_not_found
    end
  end

  test "a write refused by a later filter is still recorded" do
    sign_in @boss
    impersonate(@target)

    with_halting_write_route do
      assert_difference -> { ImpersonationEvent.count }, 1 do
        post "/halting-write"
      end
    end

    assert_response :not_found
    assert_equal "impersonation_test/halting_write#create",
                 ImpersonationEvent.order(:id).last.controller_action
  end

  test "logging out mid-impersonation closes the session" do
    sign_in @boss
    impersonate(@target)

    post "/logout"

    assert_not ImpersonationSession.order(:id).last.live?
  end
end
