require "test_helper"

# Every page in a module shares one header and tab row, and the module's
# sidebar link stays highlighted on all of them.
class BackflowModuleLayoutTest < ActionDispatch::IntegrationTest
  setup do
    @tenant = Tenant.create(name: "City of Ruston", slug: "ruston")
    @tenant.enable_module!(:backflow, by: nil)
    sign_in create_account(email: "staff@ruston.test", tenant_id: @tenant.id)
  end

  test "module pages show the module header and its tabs" do
    get "/backflow"

    assert_select "[data-module-header] h1", "Backflow Inspections"
    assert_select "[data-module-tabs] a[href=?]", "/backflow", text: "Overview"
    assert_select "[data-module-tabs] a[href=?]", "/backflow/testers", text: "Testers"
  end

  test "the current tab is marked on its own page" do
    get "/backflow"
    assert_select "[data-module-tabs] a[aria-current=page]", text: "Overview"

    get "/backflow/testers"
    assert_select "[data-module-tabs] a[aria-current=page]", text: "Testers"
  end

  test "a tab stays current on its sub-pages" do
    get "/backflow/testers/new"

    assert_select "[data-module-tabs] a[aria-current=page]", text: "Testers"
  end

  test "the module's sidebar link is highlighted on every module page" do
    [ "/backflow", "/backflow/testers", "/backflow/testers/new" ].each do |path|
      get path
      assert_select "aside a[href=?][aria-current=page]", "/backflow", { count: 1 }, "on #{path}"
    end
  end

  test "core pages do not show the module header" do
    get "/dashboard"

    assert_select "[data-module-header]", count: 0
  end
end
