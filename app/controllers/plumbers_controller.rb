class PlumbersController < ApplicationController
  include TenantScoped

  before_action :set_plumber, only: [ :edit, :update ]

  def index
    @plumbers = current_tenant.plumbers_dataset.order(:name).all
  end

  def new
    @plumber = Plumber.new
  end

  def create
    # tenant_id comes from the session, never from params, so a crafted form
    # cannot create a record inside someone else's tenant.
    @plumber = Plumber.new(plumber_params)
    @plumber.tenant_id = current_tenant.id

    if @plumber.save(raise_on_failure: false)
      redirect_to plumbers_path, notice: "#{@plumber.name} added."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    @plumber.set(plumber_params)

    if @plumber.save(raise_on_failure: false)
      redirect_to plumbers_path, notice: "#{@plumber.name} updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  # Looked up through the tenant, so another tenant's id is simply not found.
  # to_i keeps a non-numeric id (e.g. /plumbers/abc/edit) a 404 rather than a
  # PG::InvalidTextRepresentation 500.
  def set_plumber
    @plumber = current_tenant.plumbers_dataset.first(id: params[:id].to_i)

    render_not_found unless @plumber
  end

  def plumber_params
    params.require(:plumber).permit(
      :name, :company_name, :email, :phone, :cert_number, :cert_status, :cert_date, :active
    ).to_h
  end
end
