Sequel.migration do
  # The audit tables were created with `timestamp without time zone`, but their
  # two clocks disagree. Session rows are written from Ruby (Time.current, whose
  # +0000 offset a bare `timestamp` column silently discards) while event rows
  # fall through to the column default CURRENT_TIMESTAMP, which is the database
  # server's local time. On a server in America/Chicago the same instant records
  # as 17:07 in one table and 12:07 in the other, so every event appears five
  # hours before the session that contains it.
  #
  # timestamptz makes both paths store a real instant, which is what the trail
  # has to record to answer "who, and when" from the database alone.
  #
  # Both tables are empty and this feature has never shipped, so the USING
  # clause has no rows to convert. It is spelled out anyway to say what the old
  # values meant: the Ruby-written columns held UTC wall time.
  up do
    alter_table :impersonation_sessions do
      set_column_type :started_at, "timestamptz",
                      using: Sequel.lit("started_at AT TIME ZONE 'UTC'")
      set_column_type :ended_at, "timestamptz",
                      using: Sequel.lit("ended_at AT TIME ZONE 'UTC'")

      # Reading the trail by operator ("what did this admin reach?") and by
      # tenant both scan the whole table without these.
      add_index :impersonator_account_id
      add_index :tenant_id
    end

    alter_table :impersonation_events do
      set_column_type :created_at, "timestamptz",
                      using: Sequel.lit("created_at AT TIME ZONE 'UTC'")
    end
  end

  down do
    alter_table :impersonation_events do
      set_column_type :created_at, "timestamp"
    end

    alter_table :impersonation_sessions do
      drop_index :tenant_id
      drop_index :impersonator_account_id
      set_column_type :ended_at, "timestamp"
      set_column_type :started_at, "timestamp"
    end
  end
end
