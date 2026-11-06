module SuperAdmin
  # Platform → Modules: every module that exists, its platform-wide status,
  # and the tenants that have it. A module is created in code
  # (TenantModules::Registry plus its namespace), assigned to tenants from each
  # tenant's page, and enabled or disabled for the whole platform here.
  class ModulesController < BaseController
    STATUS_LABELS = { "active" => "Enabled", "disabled" => "Disabled" }.freeze

    def index
      @modules = TenantModules::Registry.all
      @statuses = PlatformModule.statuses
      # { "backflow" => [tenant, ...] } in one query; rows for keys no longer
      # in the registry are simply never looked up.
      rows = TenantModule.where(module_key: TenantModules::Registry.keys).select_map([ :module_key, :tenant_id ])
      tenants = Tenant.where(id: rows.map(&:last).uniq).order(:name).all.index_by(&:id)
      @tenants_by_module = rows.group_by(&:first).transform_values do |pairs|
        pairs.map { |_, tenant_id| tenants[tenant_id] }.compact.sort_by(&:name)
      end
    end

    def update
      definition = TenantModules::Registry.find(params[:key])
      return render_not_found unless definition

      status = params[:status].to_s
      return head :unprocessable_entity unless PlatformModule::STATUSES.include?(status)

      PlatformModule.set_status!(definition.key, status, by: current_account)
      redirect_to super_admin_modules_path, notice: "#{definition.name} is now #{STATUS_LABELS.fetch(status)}."
    end
  end
end
