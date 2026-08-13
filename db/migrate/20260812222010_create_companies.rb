Sequel.migration do
  change do
    create_table :companies do
      primary_key :id, type: :Bignum
      String :name, null: false
      citext :slug, null: false
      index :slug, unique: true
      citext :email
      String :phone
      String :street
      String :city
      String :state
      String :postal_code
      TrueClass :active, null: false, default: true
      DateTime :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      DateTime :updated_at, null: false, default: Sequel::CURRENT_TIMESTAMP
    end

    # Nullable for now: Rodauth creates an account during signup before any
    # company exists. Tighten to NOT NULL once signup assigns one.
    alter_table :accounts do
      add_foreign_key :company_id, :companies, type: :Bignum
      add_index :company_id
    end
  end
end
