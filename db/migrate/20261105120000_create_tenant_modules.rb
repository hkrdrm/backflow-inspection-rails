Sequel.migration do
  change do
    # Which modules each tenant currently has. A row means "on"; turning a
    # module off deletes the row and leaves the module's own data untouched.
    # module_key is not check-constrained: the code registry
    # (TenantModules::Registry) is the source of truth for which keys exist.
    create_table :tenant_modules do
      primary_key :id, type: :Bignum
      foreign_key :tenant_id, :tenants, type: :Bignum, null: false
      String :module_key, null: false
      column :enabled_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      # Nullable: seeds and the console enable modules with no operator.
      foreign_key :enabled_by_account_id, :accounts, type: :Bignum

      index [ :tenant_id, :module_key ], unique: true
    end

    # Append-only history of every on/off change, so who did what survives the
    # tenant_modules row being deleted.
    create_table :tenant_module_events do
      primary_key :id, type: :Bignum
      foreign_key :tenant_id, :tenants, type: :Bignum, null: false
      String :module_key, null: false
      String :action, null: false
      foreign_key :account_id, :accounts, type: :Bignum
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      constraint(:tenant_module_events_action_valid, action: %w[enabled disabled])

      index :tenant_id
    end
  end
end
