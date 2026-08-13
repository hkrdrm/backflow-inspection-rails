Sequel.migration do
  change do
    # Platform-level operator flag. Granted from the console only; it is never
    # settable through signup or any permitted-params list.
    alter_table :accounts do
      add_column :super_admin, TrueClass, null: false, default: false
    end
  end
end
