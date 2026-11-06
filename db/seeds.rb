# Development sample data. Idempotent: safe to run again with `bin/rails db:seed`.
#
# Only runs in development. These are test accounts with a shared, published
# password, so they must never exist in production.
return unless Rails.env.development?

require "bcrypt"

# Shared password for every seeded account below. Dev only.
DEV_PASSWORD = "sde-dev-password-2026".freeze

def seed_tenant(slug:, name:, city:, state:, modules: [])
  tenant = Tenant.first(slug: slug) || Tenant.create(name: name, slug: slug, city: city, state: state)
  modules.each { |key| tenant.enable_module!(key, by: nil) }
  tenant
end

# Verified accounts that can log in straight away. Existing accounts are left
# untouched, so a password changed locally is not reset by re-seeding.
def seed_account(email:, tenant:, role:)
  Account.first(email: email) || Account.create(
    email: email,
    status: 2,
    role: role,
    tenant_id: tenant.id,
    password_hash: BCrypt::Password.create(DEV_PASSWORD)
  )
end

def seed_tester(tenant:, name:, company:, cert_number:, cert_status:, account: nil)
  Plumber.first(tenant_id: tenant.id, cert_number: cert_number) || Plumber.create(
    tenant_id: tenant.id, account_id: account&.id, name: name, company_name: company,
    cert_number: cert_number, cert_status: cert_status
  )
end

# --- City of Richland, MS: has Backflow Inspections -------------------------
richland = seed_tenant(slug: "richland", name: "City of Richland", city: "Richland", state: "MS",
                       modules: [ :backflow ])
seed_account(email: "admin@richland.test", tenant: richland, role: "admin")
richland_tester = seed_account(email: "tester@richland.test", tenant: richland, role: "plumber")
seed_tester(tenant: richland, name: "Tester Richland", company: "Rankin Backflow Services",
            cert_number: "MS-BF-3101", cert_status: "verified", account: richland_tester)
seed_tester(tenant: richland, name: "Jordan Pace", company: "Pearl River Plumbing",
            cert_number: "MS-BF-3102", cert_status: "pending")

# --- Terrebonne Parish, LA: no modules yet (needs not defined) ---------------
terrebonne = seed_tenant(slug: "terrebonne", name: "Terrebonne Parish", city: "Houma", state: "LA")
seed_account(email: "admin@terrebonne.test", tenant: terrebonne, role: "admin")
seed_account(email: "staff@terrebonne.test", tenant: terrebonne, role: "admin")

puts "Seeded Richland and Terrebonne test accounts (password: see DEV_PASSWORD in db/seeds.rb)."
