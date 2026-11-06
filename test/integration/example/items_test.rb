require "test_helper"

# The Example module is the template for new modules, so its tests are the
# template for a new module's tests: who can reach it, and that each tenant
# only ever sees its own data.
class ExampleItemsTest < ActionDispatch::IntegrationTest
  setup do
    # New modules ship disabled platform-wide; these tests turn it on.
    PlatformModule.set_status!(:example, "active", by: nil)

    @tenant = Tenant.create(name: "City of Richland", slug: "richland")
    @tenant.enable_module!(:example, by: nil)
    @staff = create_account(email: "admin@richland.test", tenant_id: @tenant.id)
  end

  test "anonymous visitors are sent to login" do
    get "/example/items"

    assert_redirected_to "/login"
  end

  test "a tenant without the module gets 404" do
    other = Tenant.create(name: "Terrebonne Parish", slug: "terrebonne")
    sign_in create_account(email: "admin@terrebonne.test", tenant_id: other.id)

    get "/example"

    assert_response :not_found
  end

  test "the module is 404 everywhere while disabled platform-wide" do
    PlatformModule.set_status!(:example, "disabled", by: nil)
    sign_in @staff

    get "/example/items"

    assert_response :not_found
  end

  test "the overview renders inside the module layout" do
    sign_in @staff

    get "/example"

    assert_response :success
    assert_select "[data-breadcrumb]", /Example Module/
    assert_select "aside [data-module=example] a[href=?]", "/example/items", text: "Items"
  end

  test "staff see only their own tenant's items" do
    other = Tenant.create(name: "Terrebonne Parish", slug: "terrebonne")
    Example::Item.create(tenant_id: @tenant.id, name: "Mine")
    Example::Item.create(tenant_id: other.id, name: "Not mine")
    sign_in @staff

    get "/example/items"

    assert_select "td", text: "Mine"
    assert_select "td", { text: "Not mine", count: 0 }
  end

  test "staff add an item to their own tenant, whatever the form says" do
    other = Tenant.create(name: "Terrebonne Parish", slug: "terrebonne")
    sign_in @staff

    assert_difference -> { Example::Item.count }, 1 do
      post "/example/items", params: { item: { name: "Hydrant 12", notes: "North side", tenant_id: other.id } }
    end

    assert_redirected_to "/example/items"
    assert_equal @tenant.id, Example::Item.first(name: "Hydrant 12").tenant_id
  end

  test "an item with no name is rejected" do
    sign_in @staff

    assert_no_difference -> { Example::Item.count } do
      post "/example/items", params: { item: { name: "" } }
    end

    assert_response :unprocessable_entity
  end
end
