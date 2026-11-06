# One module switched on for one tenant. The row's existence is the switch;
# change it through Tenant#enable_module! / #disable_module!, which also write
# the audit event.
class TenantModule < Sequel::Model
  plugin :validation_helpers

  many_to_one :tenant

  def validate
    super
    validates_presence [ :tenant_id, :module_key ]
    validates_unique [ :tenant_id, :module_key ]
    validates_includes TenantModules::Registry.keys, :module_key
  end
end
