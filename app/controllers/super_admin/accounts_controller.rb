module SuperAdmin
  class AccountsController < BaseController
    def index
      @accounts = filtered_accounts.order(:email).all
      # One lookup for the whole page rather than a query per row, matching how
      # the tenants index builds its account counts.
      @tenant_names = Tenant.order(:name).to_hash(:id, :name)
    end

    private

    def filtered_accounts
      scope = Account.dataset
      scope = scope.where(tenant_id: params[:tenant_id].to_i) if params[:tenant_id].present?
      scope = scope.where(Sequel.ilike(:email, "%#{escape_like(params[:q])}%")) if params[:q].present?
      scope
    end

    # Sequel has no escape_like helper in this version, and an unescaped % in
    # the search box would silently match every account.
    def escape_like(term)
      term.to_s.gsub(/[\\%_]/) { |char| "\\#{char}" }
    end
  end
end
