Sequel.migration do
  up do
    # Platform-wide status for each module: active, disabled or planned. The
    # modules themselves are defined in code (TenantModules::Registry); a
    # module with no row here counts as disabled, so new code ships turned off.
    create_table :platform_modules do
      primary_key :id, type: :Bignum
      String :module_key, null: false, unique: true
      String :status, null: false
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      foreign_key :updated_by_account_id, :accounts, type: :Bignum

      constraint(:platform_modules_status_valid, status: %w[active disabled planned])
    end

    # Append-only history of status changes.
    create_table :platform_module_events do
      primary_key :id, type: :Bignum
      String :module_key, null: false
      String :from_status, null: false
      String :to_status, null: false
      foreign_key :account_id, :accounts, type: :Bignum
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      index :module_key
    end

    # Every module already assigned to a tenant was in use before statuses
    # existed: keep it active, or those tenants would lose it on deploy.
    # Backflow is listed explicitly as the platform's one module so far.
    keys = (self[:tenant_modules].distinct.select_map(:module_key) + [ "backflow" ]).uniq
    keys.each { |key| self[:platform_modules].insert(module_key: key, status: "active") }
  end

  down do
    drop_table :platform_module_events
    drop_table :platform_modules
  end
end
