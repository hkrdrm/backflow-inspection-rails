require "test_helper"
require "minitest/mock"

class TenantModuleTest < ActiveSupport::TestCase
  setup do
    @tenant = Tenant.create(name: "Acme Water", slug: "acme")
    @boss = create_account(email: "boss@example.com", super_admin: true)
  end

  def events
    TenantModuleEvent.where(tenant_id: @tenant.id).order(:id).all
  end

  test "a new tenant has no modules" do
    assert_not @tenant.module_enabled?(:backflow)
    assert_empty @tenant.enabled_modules
  end

  test "enabling records the module and one event" do
    assert @tenant.enable_module!(:backflow, by: @boss)

    assert @tenant.refresh.module_enabled?("backflow")
    row = TenantModule.first(tenant_id: @tenant.id, module_key: "backflow")
    assert_equal @boss.id, row.enabled_by_account_id
    assert_equal 1, events.size
    assert_equal "enabled", events.first.action
    assert_equal @boss.id, events.first.account_id
    assert_equal "backflow", events.first.module_key
  end

  test "enabling twice is a no-op" do
    @tenant.enable_module!(:backflow, by: @boss)

    assert_not @tenant.enable_module!(:backflow, by: @boss)
    assert_equal 1, events.size
  end

  # Two requests can both pass the existence check before either inserts; the
  # loser must hit the unique index and quietly report "already on".
  test "a unique-index race is treated as already enabled" do
    TenantModule.dataset.insert(tenant_id: @tenant.id, module_key: "backflow", enabled_at: Time.current)

    @tenant.stub(:module_assigned?, false) do
      assert_not @tenant.enable_module!(:backflow, by: @boss)
    end
    assert_empty events
    assert_equal 1, TenantModule.where(tenant_id: @tenant.id).count
  end

  test "disabling removes access, keeps history" do
    @tenant.enable_module!(:backflow, by: @boss)

    assert @tenant.disable_module!(:backflow, by: @boss)

    assert_not @tenant.refresh.module_enabled?(:backflow)
    assert_equal %w[enabled disabled], events.map(&:action)
  end

  test "disabling a module that is off is a no-op" do
    assert_not @tenant.disable_module!(:backflow, by: @boss)
    assert_empty events
  end

  test "re-enabling restores access with full history" do
    @tenant.enable_module!(:backflow, by: @boss)
    @tenant.disable_module!(:backflow, by: @boss)
    @tenant.enable_module!(:backflow, by: @boss)

    assert @tenant.refresh.module_enabled?(:backflow)
    assert_equal %w[enabled disabled enabled], events.map(&:action)
  end

  test "unknown keys raise" do
    assert_raises(ArgumentError) { @tenant.enable_module!(:nope, by: @boss) }
    assert_raises(ArgumentError) { @tenant.disable_module!(:nope, by: @boss) }
  end

  test "rows for modules no longer in the registry are ignored" do
    TenantModule.dataset.insert(tenant_id: @tenant.id, module_key: "retired", enabled_at: Time.current)

    assert_not @tenant.refresh.module_enabled?("retired")
    assert_empty @tenant.enabled_modules
  end

  test "enabled_modules follows registry order" do
    @tenant.enable_module!(:backflow, by: @boss)

    assert_equal [ "backflow" ], @tenant.enabled_modules.map(&:key)
  end

  test "module_enabled_at reports when a module was turned on" do
    assert_nil @tenant.module_enabled_at(:backflow)

    @tenant.enable_module!(:backflow, by: @boss)

    assert_in_delta Time.current, @tenant.module_enabled_at(:backflow), 5
  end

  test "the model rejects keys outside the registry" do
    assert_not TenantModule.new(tenant_id: @tenant.id, module_key: "nope").valid?
  end

  # --- Platform-wide status ----------------------------------------------------

  test "a module disabled platform-wide is off for tenants, but stays assigned" do
    @tenant.enable_module!(:backflow, by: @boss)
    PlatformModule.set_status!(:backflow, "disabled", by: @boss)

    @tenant.refresh
    assert_not @tenant.module_enabled?(:backflow)
    assert_empty @tenant.enabled_modules
    assert_equal [ "backflow" ], @tenant.assigned_modules.map(&:key)

    PlatformModule.set_status!(:backflow, "active", by: @boss)
    assert @tenant.refresh.module_enabled?(:backflow)
  end

  test "only active modules can be added to a tenant" do
    %w[disabled planned].each do |status|
      PlatformModule.set_status!(:backflow, status, by: @boss)

      assert_raises(PlatformModule::NotActive) { @tenant.enable_module!(:backflow, by: @boss) }
      assert_empty @tenant.refresh.assigned_modules
    end
  end

  test "a module can be removed from a tenant whatever its platform status" do
    @tenant.enable_module!(:backflow, by: @boss)
    PlatformModule.set_status!(:backflow, "disabled", by: @boss)

    assert @tenant.disable_module!(:backflow, by: @boss)
    assert_empty @tenant.refresh.assigned_modules
  end
end
