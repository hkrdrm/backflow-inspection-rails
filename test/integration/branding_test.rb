require "test_helper"

# The product is Spatial Data Engineering. "Backflow Inspections" is only the
# name of one module, never the brand.
class BrandingTest < ActionDispatch::IntegrationTest
  BRAND = "Spatial Data Engineering".freeze

  def sign_in_with_backflow
    tenant = Tenant.create(name: "City of Ruston", slug: "ruston")
    tenant.enable_module!(:backflow, by: nil)
    sign_in create_account(email: "staff@ruston.test", tenant_id: tenant.id)
  end

  def assert_no_old_brand
    assert_no_match(/backflow-(lockup|mark)|wave-(hero|band)/, response.body, "old Backflow artwork still referenced")
    assert_no_match "backflowapp.com", response.body
  end

  test "public pages carry the new brand" do
    get "/"

    assert_select "title", /#{BRAND}/
    assert_select "nav img[alt=?]", BRAND
    assert_select "footer", /© #{Date.current.year} #{BRAND}/
    assert_no_old_brand
  end

  test "the app shell carries the new brand" do
    sign_in_with_backflow

    get "/dashboard"

    assert_select "aside img[alt=?]", BRAND
    assert_no_old_brand
  end

  test "module pages carry the new brand and keep the module's name" do
    sign_in_with_backflow

    get "/backflow"

    assert_select "[data-breadcrumb]", /Backflow Inspections/
    assert_no_old_brand
  end

  test "page titles end with the brand" do
    sign_in_with_backflow

    get "/dashboard"

    assert_select "title", "Dashboard · #{BRAND}"
  end

  test "the web manifest names the product" do
    manifest = JSON.parse(Rails.public_path.join("site.webmanifest").read)

    assert_equal BRAND, manifest["name"]
    assert_equal "#0B2D4A", manifest["theme_color"]
  end
end
