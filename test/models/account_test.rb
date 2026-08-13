require "test_helper"

class AccountTest < ActiveSupport::TestCase
  test "super_admin defaults to false on a new account" do
    account = Account.create(email: "defaults@example.com", status: 1)

    assert_equal false, account.super_admin?
  end

  test "an account belongs to a tenant" do
    tenant = Tenant.create(name: "City of McComb", slug: "mccomb")
    account = create_account(email: "staff@example.com", tenant_id: tenant.id)

    assert_equal "City of McComb", account.reload.tenant.name
  end

  test "role defaults to admin on a new account" do
    account = Account.create(email: "role-default@example.com", status: 1)

    assert_equal "admin", account.role
  end

  test "the database rejects a role outside the allowed set" do
    account = Account.create(email: "bad-role@example.com", status: 1)

    assert_raises(Sequel::CheckConstraintViolation) do
      Account.where(id: account.id).update(role: "wizard")
    end
  end
end
