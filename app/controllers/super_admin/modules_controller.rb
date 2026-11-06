module SuperAdmin
  # Platform → Modules: every module that exists, with the tenants that have
  # it. Read-only: a module is created in code (TenantModules::Registry plus its
  # namespace), and assigned to tenants from each tenant's page.
  class ModulesController < BaseController
    def index
      @modules = TenantModules::Registry.all
      # { "backflow" => [tenant, ...] } in one query; rows for keys no longer
      # in the registry are simply never looked up.
      rows = TenantModule.where(module_key: TenantModules::Registry.keys).select_map([ :module_key, :tenant_id ])
      tenants = Tenant.where(id: rows.map(&:last).uniq).order(:name).all.index_by(&:id)
      @tenants_by_module = rows.group_by(&:first).transform_values do |pairs|
        pairs.map { |_, tenant_id| tenants[tenant_id] }.compact.sort_by(&:name)
      end
    end
  end
end
