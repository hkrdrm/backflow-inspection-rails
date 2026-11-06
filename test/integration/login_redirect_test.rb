require "test_helper"

# After logging in, people land somewhere useful instead of the public home
# page: their organization's overview, or the back office for platform
# operators with no organization.
class LoginRedirectTest < ActionDispatch::IntegrationTest
  test "a tenant account lands on its overview" do
    tenant = Tenant.create(name: "City of Richland", slug: "richland")

    sign_in create_account(email: "admin@richland.test", tenant_id: tenant.id)

    assert_redirected_to "/dashboard"
  end

  test "a super admin with no tenant lands in the back office" do
    sign_in create_account(email: "boss@example.com", super_admin: true)

    assert_redirected_to "/super-admin"
  end

  test "a super admin who also belongs to a tenant lands on that tenant's overview" do
    tenant = Tenant.create(name: "City of Richland", slug: "richland")

    sign_in create_account(email: "dev@example.com", super_admin: true, tenant_id: tenant.id)

    assert_redirected_to "/dashboard"
  end
end
