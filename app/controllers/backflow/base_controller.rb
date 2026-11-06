# Every controller in the backflow module inherits from this, which is what
# keeps tenants without the module out of all of it.
module Backflow
  class BaseController < ApplicationController
    include TenantScoped
    include RequiresModule

    requires_module :backflow
  end
end
