module SuperAdmin
  class AccountsController < BaseController
    # Matches Rodauth's password_minimum_length in app/misc/rodauth_main.rb.
    PASSWORD_MINIMUM_LENGTH = 8

    # `super_admin` and `status` are deliberately absent: they change only
    # through their own member actions, so privilege and lifecycle are always
    # auditable events rather than form fields. `password` is absent because it
    # is read directly and hashed, never assigned as a column. Named as a
    # constant, rather than inlined in `account_params`, so a test can assert
    # directly on the permitted set instead of relying on the `create` action's
    # `status = :verified` override to mask an accidental widening.
    PERMITTED_PARAMS = %i[email tenant_id role].freeze

    def index
      @accounts = filtered_accounts.order(:email).all
      # One lookup for the whole page rather than a query per row, matching how
      # the tenants index builds its account counts.
      @tenant_names = Tenant.order(:name).to_hash(:id, :name)
    end

    def new
      @account = Account.new
    end

    def create
      @account = Account.new(account_params)
      # Created ready to use: this flow has no verification email, the operator
      # sets the password directly.
      @account.status = :verified

      password = params[:account][:password].to_s

      if password.length < PASSWORD_MINIMUM_LENGTH
        @account.errors.add(:password, "must be at least #{PASSWORD_MINIMUM_LENGTH} characters")
        return render :new, status: :unprocessable_entity
      end

      # Writes the hash in memory only; the save below persists it.
      @account.password = password

      if @account.save(raise_on_failure: false)
        redirect_to super_admin_accounts_path, notice: "#{@account.email} created."
      else
        render :new, status: :unprocessable_entity
      end
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

    def account_params
      params.require(:account).permit(*PERMITTED_PARAMS).to_h
    end

    def tenant_options
      Tenant.order(:name).to_hash(:id, :name).map { |id, name| [ name, id ] }
    end
    helper_method :tenant_options
  end
end
