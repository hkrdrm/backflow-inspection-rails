Sequel.migration do
  change do
    # In-tenant role. Separate from the platform-level super_admin boolean:
    # a super admin has no tenant at all, so it is not a value of this column.
    alter_table :accounts do
      add_column :role, String, null: false, default: "admin"
      add_constraint(:accounts_role_valid, role: %w[admin plumber])
    end
  end
end
