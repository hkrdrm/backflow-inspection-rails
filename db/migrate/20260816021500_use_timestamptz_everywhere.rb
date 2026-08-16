Sequel.migration do
  # Every remaining timestamp column is `timestamp without time zone`, which
  # stores bare digits and no zone. That is not "stored as UTC" — it is stored
  # as nothing in particular, and it silently discards the offset Sequel sends
  # when Ruby writes a value. The impersonation audit tables were converted when
  # the two clocks writing them drifted five hours apart; this finishes the job
  # so the rule is uniform: instants live in the database, zones are a display
  # concern.
  #
  # A plain cast is the correct conversion here, not a shortcut. Postgres reads
  # an unqualified timestamp in the session's TimeZone, and every one of these
  # columns was written in exactly that zone:
  #
  #   deadline                     Sequel.date_add(CURRENT_TIMESTAMP, interval),
  #                                because rodauth-rails sets set_deadline_values?
  #                                true (Rodauth alone defaults it to MySQL only)
  #   requested_at, email_last_sent  CURRENT_TIMESTAMP column default
  #   created_at, updated_at       Sequel's :timestamps plugin, which stamps
  #                                Time.now — local, not Time.current
  #
  # So each database converts its own rows with the zone they were written in,
  # which is what makes this safe to run somewhere the server is not Chicago.
  COLUMNS = {
    account_login_change_keys: %i[deadline],
    account_password_reset_keys: %i[deadline email_last_sent],
    account_remember_keys: %i[deadline],
    account_verification_keys: %i[requested_at email_last_sent],
    plumbers: %i[created_at updated_at],
    tenants: %i[created_at updated_at]
  }.freeze

  up do
    COLUMNS.each do |table, columns|
      alter_table(table) do
        columns.each { |column| set_column_type column, "timestamptz" }
      end
    end
  end

  # Reversing drops the offset again and leaves the digits in the server's local
  # zone, which is where they started.
  down do
    COLUMNS.each do |table, columns|
      alter_table(table) do
        columns.each { |column| set_column_type column, "timestamp" }
      end
    end
  end
end
