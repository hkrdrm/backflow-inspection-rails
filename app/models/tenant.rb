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
  # Keys whose rows exist but which are no longer in TenantModules::Registry
  # (a module removed from code) are treated as off everywhere.

  def module_enabled?(key)
    enabled_module_keys.include?(key.to_s)
  end

  # Registry definitions this tenant has, in registry order.
  def enabled_modules
    TenantModules::Registry.all.select { |definition| enabled_module_keys.include?(definition.key) }
  end

  def module_enabled_at(key)
    return unless module_enabled?(key)

    tenant_modules_dataset.where(module_key: key.to_s).get(:enabled_at)
  end

  # Returns true if the module was off and is now on, false if it was already
  # on. The row and its audit event are written together or not at all.
  def enable_module!(key, by:)
    key = registered_module_key!(key)
    return false if module_enabled?(key)

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
    @enabled_module_keys = nil
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
    @enabled_module_keys = nil
  end

  def refresh
    @enabled_module_keys = nil
    super
  end

  def validate
    super
    validates_presence [ :name, :slug ]
    validates_unique :slug
  end

  private

  # Memoized per instance; current_tenant is memoized per request, so the
  # sidebar, dashboard and module guard share one query.
  def enabled_module_keys
    @enabled_module_keys ||= tenant_modules_dataset.select_map(:module_key) & TenantModules::Registry.keys
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
