require "test_helper"

class SuperAdminCompaniesTest < ActionDispatch::IntegrationTest
  setup do
    sign_in create_account(email: "boss@example.com", super_admin: true)
  end

  test "renders the new company form" do
    get "/super-admin/companies/new"

    assert_response :success
  end

  test "renders the edit form for an existing company" do
    company = Company.create(name: "Acme", slug: "acme")

    get "/super-admin/companies/#{company.id}/edit"

    assert_response :success
  end

  test "returns 404 for a company that does not exist" do
    get "/super-admin/companies/999999/edit"

    assert_response :not_found
  end

  test "creates a company" do
    assert_difference -> { Company.count }, 1 do
      post "/super-admin/companies", params: {
        company: { name: "Acme Backflow", slug: "acme-backflow", city: "McComb", state: "MS" }
      }
    end

    assert_redirected_to "/super-admin/companies"
    assert_equal "McComb", Company.first(slug: "acme-backflow").city
  end

  test "rejects a company with no name" do
    assert_no_difference -> { Company.count } do
      post "/super-admin/companies", params: { company: { name: "", slug: "nameless" } }
    end

    assert_response 422
  end

  test "rejects a duplicate slug regardless of case" do
    Company.create(name: "First", slug: "acme")

    assert_no_difference -> { Company.count } do
      post "/super-admin/companies", params: { company: { name: "Second", slug: "ACME" } }
    end

    assert_response 422
  end

  test "updates a company" do
    company = Company.create(name: "Old Name", slug: "old-name")

    patch "/super-admin/companies/#{company.id}", params: { company: { name: "New Name" } }

    assert_equal "New Name", company.reload.name
  end

  test "deactivating keeps the company row" do
    company = Company.create(name: "Acme", slug: "acme")

    patch "/super-admin/companies/#{company.id}/deactivate"

    assert_equal false, company.reload.active?
    assert_equal 1, Company.where(id: company.id).count
  end

  test "activating restores an inactive company" do
    company = Company.create(name: "Acme", slug: "acme", active: false)

    patch "/super-admin/companies/#{company.id}/activate"

    assert_equal true, company.reload.active?
  end

  test "ignores params outside the permitted list" do
    company = Company.create(name: "Acme", slug: "acme")

    patch "/super-admin/companies/#{company.id}", params: {
      company: { name: "Renamed", id: company.id + 1000 }
    }

    assert_equal "Renamed", company.reload.name
  end
end
