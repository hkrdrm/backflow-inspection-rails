module SuperAdmin
  # Switches one module on or off for one tenant. Each change is its own
  # action, like activate/deactivate on tenants, and is attributed to the
  # operator in tenant_module_events. The super admin area is unreachable
  # mid-impersonation, so current_account here is always the real operator.
  class TenantModulesController < BaseController
    before_action :set_tenant
    before_action :set_definition

    # The "Add module" form on the tenant page, which sends the key in the body.
    def create
      @tenant.enable_module!(@definition.key, by: current_account)
      redirect_to edit_super_admin_tenant_path(@tenant),
                  notice: "#{@definition.name} added to #{@tenant.name}."
    end

    def enable
      @tenant.enable_module!(@definition.key, by: current_account)
      redirect_to edit_super_admin_tenant_path(@tenant),
                  notice: "#{@definition.name} enabled for #{@tenant.name}."
    end

    def disable
      @tenant.disable_module!(@definition.key, by: current_account)
      redirect_to edit_super_admin_tenant_path(@tenant),
                  notice: "#{@definition.name} disabled for #{@tenant.name}."
    end

    private

    # to_i keeps a non-numeric id a 404 rather than a
    # PG::InvalidTextRepresentation 500.
    def set_tenant
      @tenant = Tenant[params[:tenant_id].to_i]

      render_not_found unless @tenant
    end

    def set_definition
      @definition = TenantModules::Registry.find(params[:key])

      render_not_found unless @definition
    end
  end
end
