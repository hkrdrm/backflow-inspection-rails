module SuperAdmin
  class CompaniesController < BaseController
    before_action :set_company, only: [ :edit, :update, :activate, :deactivate ]

    def index
      @companies = Company.order(:name).all
      @account_counts = Account.where(company_id: @companies.map(&:id))
                               .group_and_count(:company_id)
                               .to_hash(:company_id, :count)
    end

    def new
      @company = Company.new
    end

    def create
      @company = Company.new(company_params)

      if @company.save(raise_on_failure: false)
        redirect_to super_admin_companies_path, notice: "#{@company.name} created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      @company.set(company_params)

      if @company.save(raise_on_failure: false)
        redirect_to super_admin_companies_path, notice: "#{@company.name} updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def activate
      @company.update(active: true)
      redirect_to super_admin_companies_path, notice: "#{@company.name} activated."
    end

    def deactivate
      @company.update(active: false)
      redirect_to super_admin_companies_path, notice: "#{@company.name} deactivated."
    end

    private

    def set_company
      @company = Company[params[:id]]

      render_not_found unless @company
    end

    # `active` is deliberately absent: it changes only through the activate and
    # deactivate actions, so there is one way to take a tenant offline.
    def company_params
      params.require(:company).permit(
        :name, :slug, :email, :phone, :street, :city, :state, :postal_code
      ).to_h
    end
  end
end
