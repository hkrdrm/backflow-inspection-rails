module SuperAdmin
  class TenantsController < BaseController
    before_action :set_tenant, only: [ :edit, :update, :activate, :deactivate ]

    def index
      @tenants = Tenant.order(:name).all
      @account_counts = Account.where(tenant_id: @tenants.map(&:id))
                               .group_and_count(:tenant_id)
                               .to_hash(:tenant_id, :count)
    end

    def new
      @tenant = Tenant.new
    end

    def create
      @tenant = Tenant.new(tenant_params)

      if @tenant.save(raise_on_failure: false)
        redirect_to super_admin_tenants_path, notice: "#{@tenant.name} created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      @tenant.set(tenant_params)

      if @tenant.save(raise_on_failure: false)
        redirect_to super_admin_tenants_path, notice: "#{@tenant.name} updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def activate
      @tenant.update(active: true)
      redirect_to super_admin_tenants_path, notice: "#{@tenant.name} activated."
    end

    def deactivate
      @tenant.update(active: false)
      redirect_to super_admin_tenants_path, notice: "#{@tenant.name} deactivated."
    end

    private

    # Looked up by id, so to_i keeps a non-numeric id (e.g.
    # /super-admin/tenants/abc/edit) a 404 rather than a
    # PG::InvalidTextRepresentation 500.
    def set_tenant
      @tenant = Tenant[params[:id].to_i]

      render_not_found unless @tenant
    end

    # `active` is deliberately absent: it changes only through the activate and
    # deactivate actions, so there is one way to take a tenant offline.
    def tenant_params
      params.require(:tenant).permit(
        :name, :slug, :email, :phone, :street, :city, :state, :postal_code
      ).to_h
    end
  end
end
