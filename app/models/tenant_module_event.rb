# Append-only record of a module being switched on or off for a tenant, and by
# whom (nil when done from seeds or the console).
class TenantModuleEvent < Sequel::Model
  many_to_one :tenant
  many_to_one :account
end
