require "test_helper"

class SuperAdminTenantsTest < ActionDispatch::IntegrationTest
  setup do
    sign_in create_account(email: "boss@example.com", super_admin: true)
  end

  test "renders the new tenant form" do
    get "/super-admin/tenants/new"

    assert_response :success
  end

  test "renders the edit form for an existing tenant" do
    tenant = Tenant.create(name: "Acme", slug: "acme")

    get "/super-admin/tenants/#{tenant.id}/edit"

    assert_response :success
  end

  test "returns 404 for a tenant that does not exist" do
    get "/super-admin/tenants/999999/edit"

    assert_response :not_found
  end

  test "creates a tenant" do
    assert_difference -> { Tenant.count }, 1 do
      post "/super-admin/tenants", params: {
        tenant: { name: "Acme Backflow", slug: "acme-backflow", city: "McComb", state: "MS" }
      }
    end

    assert_redirected_to "/super-admin/tenants"
    assert_equal "McComb", Tenant.first(slug: "acme-backflow").city
  end

  test "rejects a tenant with no name" do
    assert_no_difference -> { Tenant.count } do
      post "/super-admin/tenants", params: { tenant: { name: "", slug: "nameless" } }
    end

    assert_response 422
  end

  test "rejects a duplicate slug regardless of case" do
    Tenant.create(name: "First", slug: "acme")

    assert_no_difference -> { Tenant.count } do
      post "/super-admin/tenants", params: { tenant: { name: "Second", slug: "ACME" } }
    end

    assert_response 422
  end

  test "updates a tenant" do
    tenant = Tenant.create(name: "Old Name", slug: "old-name")

    patch "/super-admin/tenants/#{tenant.id}", params: { tenant: { name: "New Name" } }

    assert_equal "New Name", tenant.reload.name
  end

  test "deactivating keeps the tenant row" do
    tenant = Tenant.create(name: "Acme", slug: "acme")

    patch "/super-admin/tenants/#{tenant.id}/deactivate"

    assert_equal false, tenant.reload.active?
    assert_equal 1, Tenant.where(id: tenant.id).count
  end

  test "activating restores an inactive tenant" do
    tenant = Tenant.create(name: "Acme", slug: "acme", active: false)

    patch "/super-admin/tenants/#{tenant.id}/activate"

    assert_equal true, tenant.reload.active?
  end

  test "ignores params outside the permitted list" do
    tenant = Tenant.create(name: "Acme", slug: "acme")

    patch "/super-admin/tenants/#{tenant.id}", params: {
      tenant: { name: "Renamed", id: tenant.id + 1000 }
    }

    assert_equal "Renamed", tenant.reload.name
  end
end
