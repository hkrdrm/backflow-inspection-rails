class Tenant < Sequel::Model
  plugin :validation_helpers
  plugin :boolean_readers
  # Gives Sequel models the naming/to_key interface form_with needs.
  plugin :active_model
  plugin :timestamps, update_on_create: true

  one_to_many :accounts
  one_to_many :plumbers
  one_to_many :tenant_modules

  # --- Modules -------------------------------------------------------------
  #
  # Two levels: a module is *assigned* to a tenant (a tenant_modules row), and
  # *enabled* for it when it is also active platform-wide (PlatformModule). A
  # module disabled platform-wide stays assigned but is off.
  # Keys whose rows exist but which are no longer in TenantModules::Registry
  # (a module removed from code) are treated as off everywhere.

  def module_enabled?(key)
    enabled_module_keys.include?(key.to_s)
  end

  # Registry definitions this tenant can use, in registry order.
  def enabled_modules
    TenantModules::Registry.all.select { |definition| enabled_module_keys.include?(definition.key) }
  end

  def module_assigned?(key)
    assigned_module_keys.include?(key.to_s)
  end

  # Registry definitions assigned to this tenant, whatever their platform status.
  def assigned_modules
    TenantModules::Registry.all.select { |definition| assigned_module_keys.include?(definition.key) }
  end

  def module_enabled_at(key)
    return unless module_assigned?(key)

    tenant_modules_dataset.where(module_key: key.to_s).get(:enabled_at)
  end

  # Returns true if the module was off and is now on, false if it was already
  # on. The row and its audit event are written together or not at all. Only
  # modules active platform-wide can be added (PlatformModule::NotActive).
  def enable_module!(key, by:)
    key = registered_module_key!(key)
    raise PlatformModule::NotActive, "#{key} is not active platform-wide" unless PlatformModule.status_for(key) == "active"
    return false if module_assigned?(key)

    db.transaction do
      # Savepoint so that losing a race to the unique index rolls back only the
      # insert, not a transaction the caller may be inside.
      inserted = begin
        db.transaction(savepoint: true) do
          TenantModule.dataset.insert(tenant_id: id, module_key: key,
                                      enabled_at: Time.current, enabled_by_account_id: by&.id)
        end
        true
      rescue Sequel::UniqueConstraintViolation
        false
      end

      record_module_event(key, "enabled", by) if inserted
      inserted
    end
  ensure
    clear_module_memo
  end

  # Returns true if the module was on and is now off. Only the switch is
  # removed; the module's own data stays, and returns if it is re-enabled.
  def disable_module!(key, by:)
    key = registered_module_key!(key)

    db.transaction do
      removed = tenant_modules_dataset.where(module_key: key).delete.positive?
      record_module_event(key, "disabled", by) if removed
      removed
    end
  ensure
    clear_module_memo
  end

  def refresh
    clear_module_memo
    super
  end

  def validate
    super
    validates_presence [ :name, :slug ]
    validates_unique :slug
  end

  private

  # Memoized per instance; current_tenant is memoized per request, so the
  # sidebar, dashboard and module guard share these queries.
  def assigned_module_keys
    @assigned_module_keys ||= tenant_modules_dataset.select_map(:module_key) & TenantModules::Registry.keys
  end

  def enabled_module_keys
    @enabled_module_keys ||= assigned_module_keys & PlatformModule.active_keys
  end

  def clear_module_memo
    @assigned_module_keys = nil
    @enabled_module_keys = nil
  end

  def registered_module_key!(key)
    TenantModules::Registry.find(key)&.key or raise ArgumentError, "unknown module: #{key}"
  end

  # Stamped in Ruby rather than by the column default: CURRENT_TIMESTAMP is the
  # transaction's start time, which would misorder events written in one
  # transaction (see Impersonation#record_impersonated_write).
  def record_module_event(key, action, by)
    TenantModuleEvent.create(tenant_id: id, module_key: key, action: action,
                             account_id: by&.id, created_at: Time.current)
  end
end
