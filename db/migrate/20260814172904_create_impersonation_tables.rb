Sequel.migration do
  change do
    create_table :impersonation_sessions do
      primary_key :id, type: :Bignum
      foreign_key :impersonator_account_id, :accounts, type: :Bignum, null: false
      foreign_key :impersonated_account_id, :accounts, type: :Bignum, null: false
      # The target's tenant at the time. Denormalized on purpose: reassigning
      # the account later must not rewrite the record of who was reached.
      foreign_key :tenant_id, :tenants, type: :Bignum
      String :ip_address
      DateTime :started_at, null: false, default: Sequel::CURRENT_TIMESTAMP
      # NULL means the impersonation is still live.
      DateTime :ended_at

      index :impersonated_account_id
    end

    create_table :impersonation_events do
      primary_key :id, type: :Bignum
      foreign_key :impersonation_session_id, :impersonation_sessions,
                  type: :Bignum, null: false
      String :request_method, null: false
      String :path, null: false
      String :controller_action, null: false
      DateTime :created_at, null: false, default: Sequel::CURRENT_TIMESTAMP

      index :impersonation_session_id
    end
  end
end
