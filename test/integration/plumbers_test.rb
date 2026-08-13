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
end
