require "test_helper"

# Inside a module, the sidebar expands that module to list its pages and the
# main area shows a breadcrumb (home › module › page).
class BackflowModuleLayoutTest < ActionDispatch::IntegrationTest
  setup do
    @tenant = Tenant.create(name: "City of Ruston", slug: "ruston")
    @tenant.enable_module!(:backflow, by: nil)
    sign_in create_account(email: "staff@ruston.test", tenant_id: @tenant.id)
  end

  test "the breadcrumb names the module and the current page" do
    get "/backflow/testers"

    assert_select "[data-breadcrumb] a[href=?]", "/dashboard"
    assert_select "[data-breadcrumb] a[href=?]", "/backflow", text: "Backflow Inspections"
    assert_select "[data-breadcrumb] [aria-current=page]", text: "Testers"
  end

  test "the breadcrumb follows a page onto its sub-pages" do
    get "/backflow/testers/new"

    assert_select "[data-breadcrumb] [aria-current=page]", text: "Testers"
  end

  test "the current module lists its pages in the sidebar" do
    get "/backflow"

    assert_select "aside [data-module=backflow] a[href=?]", "/backflow", text: "Overview"
    assert_select "aside [data-module=backflow] a[href=?]", "/backflow/testers", text: "Testers"
  end

  test "the current page is marked in the sidebar, including on sub-pages" do
    { "/backflow" => "/backflow", "/backflow/testers" => "/backflow/testers",
      "/backflow/testers/new" => "/backflow/testers" }.each do |visit, marked|
      get visit
      assert_select "aside [data-module-pages] a[aria-current=page]", { count: 1 }, "one current page on #{visit}"
      assert_select "aside [data-module-pages] a[href=?][aria-current=page]", marked, { count: 1 }, "on #{visit}"
    end
  end

  test "outside the module its pages stay collapsed" do
    get "/dashboard"

    assert_select "aside a[href=?]", "/backflow", count: 1
    assert_select "aside [data-module-pages]", count: 0
  end

  test "the module tab row is gone" do
    get "/backflow"

    assert_select "[data-module-tabs]", count: 0
  end
end
