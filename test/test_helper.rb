ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "bcrypt"

module ActiveSupport
  class TestCase
    # This app uses Sequel, not Active Record, so there is no per-worker test
    # database remapping and no `fixtures :all`. Tests run in a single process
    # against one test database, each wrapped in a transaction that is rolled
    # back afterwards.
    parallelize(workers: 1)

    # `rails/test_help` mixes ActiveRecord::TestFixtures into every test case
    # whenever ActiveRecord::Base is defined — and it is here, because the
    # solid_cache/solid_queue/solid_cable gems load Active Record even though
    # this app never uses it. With no Active Record connection configured,
    # its fixture hooks raise. Neutralize them.
    def setup_fixtures(*)
    end

    def teardown_fixtures(*)
    end

    def run(*args)
      result = nil
      Sequel::Model.db.transaction(rollback: :always, savepoint: true) do
        result = super
      end
      result
    end

    TEST_PASSWORD = "correct horse battery"

    # Creates a verified account that can log in through Rodauth.
    def create_account(email:, super_admin: false, tenant_id: nil)
      Account.create(
        email: email,
        status: 2,
        password_hash: BCrypt::Password.create(TEST_PASSWORD, cost: BCrypt::Engine::MIN_COST),
        super_admin: super_admin,
        tenant_id: tenant_id
      )
    end
  end
end

class ActionDispatch::IntegrationTest
  # Logs in through the real Rodauth form so tests exercise the same session
  # handling the app uses in production.
  def sign_in(account)
    post "/login", params: { "email" => account.email, "password" => TEST_PASSWORD }
  end
end
