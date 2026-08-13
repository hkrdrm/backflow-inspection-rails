class PlumbersController < ApplicationController
  include TenantScoped

  def index
    @plumbers = current_tenant.plumbers_dataset.order(:name).all
  end
end
