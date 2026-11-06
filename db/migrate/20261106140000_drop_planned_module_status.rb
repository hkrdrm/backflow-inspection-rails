Sequel.migration do
  # Module status is now just active (shown as "Enabled") or disabled. Any
  # module marked planned is turned off, which is what planned already meant
  # for tenants.
  up do
    self[:platform_modules].where(status: "planned").update(status: "disabled", updated_at: Sequel::CURRENT_TIMESTAMP)
    alter_table(:platform_modules) do
      drop_constraint :platform_modules_status_valid
      add_constraint(:platform_modules_status_valid, status: %w[active disabled])
    end
  end

  down do
    alter_table(:platform_modules) do
      drop_constraint :platform_modules_status_valid
      add_constraint(:platform_modules_status_valid, status: %w[active disabled planned])
    end
  end
end
