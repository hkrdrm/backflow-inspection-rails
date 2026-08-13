require "test_helper"

class AccountTest < ActiveSupport::TestCase
  test "super_admin defaults to false on a new account" do
    account = Account.create(email: "defaults@example.com", status: 1)

    assert_equal false, account.super_admin?
  end
end
