require "test_helper"

class PlumberTest < ActiveSupport::TestCase
  def tenant(slug: "mccomb", name: "City of McComb")
    Tenant.create(name: name, slug: slug)
  end

  test "cert_status defaults to pending and active defaults to true" do
    plumber = Plumber.create(tenant_id: tenant.id, name: "Dale Pike", cert_number: "MS-1001")

    assert_equal "pending", plumber.cert_status
    assert_equal true, plumber.active?
  end

  test "timestamps are set on create" do
    plumber = Plumber.create(tenant_id: tenant.id, name: "Dale Pike", cert_number: "MS-1001")

    assert_not_nil plumber.created_at
    assert_not_nil plumber.updated_at
  end

  test "name and cert_number are required" do
    plumber = Plumber.new(tenant_id: tenant.id)

    assert_not plumber.valid?
    assert_includes plumber.errors.keys, :name
    assert_includes plumber.errors.keys, :cert_number
  end

  test "cert_number must be unique within a tenant" do
    one = tenant
    Plumber.create(tenant_id: one.id, name: "Dale Pike", cert_number: "MS-1001")

    duplicate = Plumber.new(tenant_id: one.id, name: "Someone Else", cert_number: "MS-1001")

    assert_not duplicate.valid?
    assert_includes duplicate.errors.keys, [ :tenant_id, :cert_number ]
  end

  test "the same cert_number is allowed in a different tenant" do
    Plumber.create(tenant_id: tenant.id, name: "Dale Pike", cert_number: "MS-1001")
    other = tenant(slug: "summit", name: "City of Summit")

    plumber = Plumber.new(tenant_id: other.id, name: "Dale Pike", cert_number: "MS-1001")

    assert plumber.valid?
  end

  test "an invalid cert_status is rejected" do
    plumber = Plumber.new(tenant_id: tenant.id, name: "Dale Pike", cert_number: "MS-1001",
                          cert_status: "vibes")

    assert_not plumber.valid?
    assert_includes plumber.errors.keys, :cert_status
  end

  test "a plumber can exist without an account" do
    plumber = Plumber.create(tenant_id: tenant.id, name: "Dale Pike", cert_number: "MS-1001")

    assert_nil plumber.account_id
    assert_nil plumber.account
  end

  test "a tenant lists its plumbers" do
    one = tenant
    Plumber.create(tenant_id: one.id, name: "Dale Pike", cert_number: "MS-1001")

    assert_equal [ "Dale Pike" ], one.reload.plumbers.map(&:name)
  end
end
