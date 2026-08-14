require "test_helper"

class ImpersonationSessionTest < ActiveSupport::TestCase
  setup do
    @tenant = Tenant.create(name: "Acme", slug: "acme")
    @boss = create_account(email: "boss@example.com", super_admin: true)
    @target = create_account(email: "target@acme.test", tenant_id: @tenant.id)
  end

  def start_session
    ImpersonationSession.create(
      impersonator_account_id: @boss.id,
      impersonated_account_id: @target.id,
      tenant_id: @tenant.id,
      ip_address: "203.0.113.10",
      started_at: Time.current
    )
  end

  test "records who impersonated whom" do
    session = start_session

    assert_equal @boss.id, session.impersonator.id
    assert_equal @target.id, session.impersonated.id
    assert_equal @tenant.id, session.tenant.id
  end

  test "is live until it is ended" do
    session = start_session

    assert session.live?

    session.update(ended_at: Time.current)

    assert_not session.live?
  end

  test "collects the events recorded during it" do
    session = start_session
    ImpersonationEvent.create(
      impersonation_session_id: session.id,
      request_method: "POST",
      path: "/plumbers",
      controller_action: "plumbers#create"
    )

    assert_equal [ "plumbers#create" ], session.impersonation_events.map(&:controller_action)
  end
end
