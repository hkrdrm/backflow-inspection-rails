# Every controller in a module inherits from its BaseController, which is
# what keeps tenants without the module (or while it's off platform-wide) out
# of all of it. Copy this file and change the key.
module Example
  class BaseController < ApplicationController
    include TenantScoped
    include RequiresModule

    requires_module :example

    # Sidebar pages and breadcrumb around every page; see layouts/tenant_module.
    layout "tenant_module"
  end
end
