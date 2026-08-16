require "test_helper"

# A `timestamp without time zone` column stores bare digits and no zone, so it
# silently drops the offset Ruby sends and reads back in whatever zone the
# process happens to run in. That is how the impersonation audit trail came to
# record events five hours before the sessions containing them. The rule is now
# uniform -- instants in the database, zones at the edges -- and this is what
# keeps a future migration from quietly reintroducing the old kind.
class SchemaTest < ActiveSupport::TestCase
  test "every timestamp column stores an absolute instant" do
    naive = Sequel::Model.db[
      "SELECT table_name, column_name
       FROM information_schema.columns
       WHERE table_schema = ? AND data_type = ?
       ORDER BY table_name, ordinal_position",
      "public", "timestamp without time zone"
    ].map { |r| "#{r[:table_name]}.#{r[:column_name]}" }

    assert_empty naive,
                 "these columns cannot record an instant -- use timestamptz:\n" \
                 "  #{naive.join("\n  ")}"
  end
end
