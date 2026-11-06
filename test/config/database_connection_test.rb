require "test_helper"

# A pooled connection the server has dropped (Postgres restarted, an idle SSL
# connection timed out) used to surface as PG::ConnectionBad and a 500 on the
# next request. The connection validator checks idle connections before
# handing them out and replaces dead ones instead.
class DatabaseConnectionTest < ActiveSupport::TestCase
  test "pooled connections are validated before reuse" do
    pool = Sequel::Model.db.pool

    assert_respond_to pool, :connection_validation_timeout, "connection_validator extension is not loaded"
    assert_equal 60, pool.connection_validation_timeout
  end
end
