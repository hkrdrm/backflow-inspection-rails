Sequel.migration do
  change do
    # The example module's data. Module tables are prefixed with the module's
    # key and always carry tenant_id: every row belongs to exactly one tenant.
    create_table :example_items do
      primary_key :id, type: :Bignum
      foreign_key :tenant_id, :tenants, type: :Bignum, null: false
      String :name, null: false
      String :notes, text: true
      column :created_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP
      column :updated_at, :timestamptz, null: false, default: Sequel::CURRENT_TIMESTAMP

      index :tenant_id
    end
  end
end
