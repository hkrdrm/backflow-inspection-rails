# Gates a controller behind one module. Include after TenantScoped, so an
# anonymous visitor still goes to login and an inactive tenant still 404s
# before the module is even considered:
#
#   include TenantScoped
#   include RequiresModule
#   requires_module :backflow
#
# A tenant without the module gets a 404, the same as for anything else hidden.
# Each module's BaseController does this once, so no controller in the module
# can forget it.
module RequiresModule
  extend ActiveSupport::Concern

  class_methods do
    def requires_module(key)
      definition = TenantModules::Registry.find(key)
      # Fail at load time: a typo here would otherwise 404 every tenant.
      raise ArgumentError, "unknown module: #{key}" unless definition

      before_action { render_not_found unless current_tenant.module_enabled?(definition.key) }
    end
  end
end
