Sequel.migration do
  change do
    rename_table :companies, :tenants

    alter_table :accounts do
      rename_column :company_id, :tenant_id
    end
  end
end
