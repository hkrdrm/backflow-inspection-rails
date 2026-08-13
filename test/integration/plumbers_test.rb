require "test_helper"

class PlumbersTest < ActionDispatch::IntegrationTest
  def setup_tenant(slug:, name:)
    Tenant.create(name: name, slug: slug)
  end

  test "anonymous visitor is sent to login" do
    get "/plumbers"

    assert_redirected_to "/login"
  end

  test "an account with no tenant gets 404" do
    sign_in create_account(email: "nobody@example.com")

    get "/plumbers"

    assert_response :not_found
  end

  test "staff see their own tenant's plumbers" do
    tenant = setup_tenant(slug: "mccomb", name: "City of McComb")
    Plumber.create(tenant_id: tenant.id, name: "Dale Pike", cert_number: "MS-1001")
    sign_in create_account(email: "staff@example.com", tenant_id: tenant.id)

    get "/plumbers"

    assert_response :success
    assert_select "td", /Dale Pike/
  end

  test "staff never see another tenant's plumbers" do
    mine = setup_tenant(slug: "mccomb", name: "City of McComb")
    theirs = setup_tenant(slug: "summit", name: "City of Summit")
    Plumber.create(tenant_id: theirs.id, name: "Not Mine", cert_number: "MS-2002")
    sign_in create_account(email: "staff@example.com", tenant_id: mine.id)

    get "/plumbers"

    assert_response :success
    assert_select "td", { text: /Not Mine/, count: 0 }
  end

  test "staff of a deactivated tenant are locked out" do
    tenant = setup_tenant(slug: "summit", name: "City of Summit")
    Plumber.create(tenant_id: tenant.id, name: "Dale Pike", cert_number: "MS-1001")
    tenant.update(active: false)
    sign_in create_account(email: "staff@example.com", tenant_id: tenant.id)

    get "/plumbers"

    assert_response :not_found
  end

  test "staff create a plumber in their own tenant" do
    tenant = setup_tenant(slug: "mccomb", name: "City of McComb")
    sign_in create_account(email: "staff@example.com", tenant_id: tenant.id)

    assert_difference -> { Plumber.count }, 1 do
      post "/plumbers", params: {
        plumber: { name: "Dale Pike", company_name: "Pike Plumbing Co.", cert_number: "MS-1001" }
      }
    end

    assert_redirected_to "/plumbers"
    assert_equal tenant.id, Plumber.first(cert_number: "MS-1001").tenant_id
  end

  test "a plumber cannot be created into another tenant" do
    mine = setup_tenant(slug: "mccomb", name: "City of McComb")
    theirs = setup_tenant(slug: "summit", name: "City of Summit")
    sign_in create_account(email: "staff@example.com", tenant_id: mine.id)

    post "/plumbers", params: {
      plumber: { name: "Dale Pike", cert_number: "MS-1001", tenant_id: theirs.id }
    }

    assert_equal mine.id, Plumber.first(cert_number: "MS-1001").tenant_id
  end

  test "a plumber with no name is rejected" do
    tenant = setup_tenant(slug: "mccomb", name: "City of McComb")
    sign_in create_account(email: "staff@example.com", tenant_id: tenant.id)

    assert_no_difference -> { Plumber.count } do
      post "/plumbers", params: { plumber: { name: "", cert_number: "MS-1001" } }
    end

    assert_response 422
  end

  test "staff update a plumber in their own tenant" do
    tenant = setup_tenant(slug: "mccomb", name: "City of McComb")
    plumber = Plumber.create(tenant_id: tenant.id, name: "Dale Pike", cert_number: "MS-1001")
    sign_in create_account(email: "staff@example.com", tenant_id: tenant.id)

    patch "/plumbers/#{plumber.id}", params: { plumber: { cert_status: "verified" } }

    assert_equal "verified", plumber.reload.cert_status
  end

  test "another tenant's plumber cannot be edited" do
    mine = setup_tenant(slug: "mccomb", name: "City of McComb")
    theirs = setup_tenant(slug: "summit", name: "City of Summit")
    plumber = Plumber.create(tenant_id: theirs.id, name: "Not Mine", cert_number: "MS-2002")
    sign_in create_account(email: "staff@example.com", tenant_id: mine.id)

    get "/plumbers/#{plumber.id}/edit"

    assert_response :not_found
  end
end
