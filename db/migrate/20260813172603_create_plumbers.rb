Sequel.migration do
  change do
    create_table :plumbers do
      primary_key :id, type: :Bignum
      foreign_key :tenant_id, :tenants, type: :Bignum, null: false
      # Nullable: the utility supplies the approved-tester list, and a plumber
      # claims their row later by registering with a matching cert_number.
      foreign_key :account_id, :accounts, type: :Bignum
      String :name, null: false
      String :company_name
      citext :email
      String :phone
      String :cert_number, null: false
      String :cert_status, null: false, default: "pending"
      Date :cert_date
      TrueClass :active, null: false, default: true
      DateTime :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      DateTime :updated_at, null: false, default: Sequel::CURRENT_TIMESTAMP

      constraint(:plumbers_cert_status_valid,
                 cert_status: %w[pending verified expired revoked])

      index [ :tenant_id, :cert_number ], unique: true
      index :account_id
    end
  end
end
