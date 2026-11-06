require "test_helper"

class PlatformModuleTest < ActiveSupport::TestCase
  setup do
    @boss = create_account(email: "boss@example.com", super_admin: true)
  end

  def events
    PlatformModuleEvent.order(:id).all
  end

  test "backflow is active (marked by the data migration)" do
    assert_equal "active", PlatformModule.status_for(:backflow)
    assert_includes PlatformModule.active_keys, "backflow"
  end

  # New code ships turned off everywhere until a super admin activates it.
  test "a module with no row counts as disabled" do
    PlatformModule.where(module_key: "backflow").delete

    assert_equal "disabled", PlatformModule.status_for("backflow")
    assert_not_includes PlatformModule.active_keys, "backflow"
  end

  test "changing status records who changed it, from what, to what" do
    assert PlatformModule.set_status!(:backflow, "planned", by: @boss)

    assert_equal "planned", PlatformModule.status_for(:backflow)
    event = events.last
    assert_equal [ "backflow", "active", "planned", @boss.id ],
                 [ event.module_key, event.from_status, event.to_status, event.account_id ]
  end

  test "setting a module with no row creates it" do
    PlatformModule.where(module_key: "backflow").delete

    assert PlatformModule.set_status!(:backflow, "active", by: @boss)

    assert_equal "active", PlatformModule.status_for(:backflow)
    assert_equal [ "disabled", "active" ], [ events.last.from_status, events.last.to_status ]
  end

  test "setting the current status is a no-op" do
    assert_not PlatformModule.set_status!(:backflow, "active", by: @boss)
    assert_empty events
  end

  test "unknown statuses and modules are rejected" do
    assert_raises(ArgumentError) { PlatformModule.set_status!(:backflow, "retired", by: @boss) }
    assert_raises(ArgumentError) { PlatformModule.set_status!(:nope, "active", by: @boss) }
  end
end
