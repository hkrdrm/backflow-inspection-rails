module SuperAdmin
  class AccountsController < BaseController
    before_action :set_account,
                  only: [ :edit, :update, :close, :reopen, :grant_super_admin, :revoke_super_admin ]

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

    def edit
    end

    def update
      @account.set(account_params)

      password = params[:account][:password].to_s

      if password.present?
        if password.length < PASSWORD_MINIMUM_LENGTH
          @account.errors.add(:password, "must be at least #{PASSWORD_MINIMUM_LENGTH} characters")
          return render :edit, status: :unprocessable_entity
        end

        @account.password = password
      end

      if @account.save(raise_on_failure: false)
        redirect_to super_admin_accounts_path, notice: "#{@account.email} updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def close
      return refuse("You cannot close your own account.") if own_account?

      @account.update(status: :closed)
      redirect_to super_admin_accounts_path, notice: "#{@account.email} closed."
    end

    def reopen
      @account.status = :verified

      if @account.save(raise_on_failure: false)
        redirect_to super_admin_accounts_path, notice: "#{@account.email} reopened."
      else
        # The partial unique index only covers open accounts, so another account
        # may have taken this email while this one was closed.
        refuse("#{@account.email} cannot be reopened: that email belongs to an open account.")
      end
    end

    def grant_super_admin
      @account.update(super_admin: true)
      redirect_to super_admin_accounts_path, notice: "#{@account.email} is now a super admin."
    end

    def revoke_super_admin
      return refuse("You cannot revoke your own super admin access.") if own_account?

      @account.update(super_admin: false)
      redirect_to super_admin_accounts_path, notice: "#{@account.email} is no longer a super admin."
    end

    private

    # Looked up by id, so to_i keeps a non-numeric id (e.g.
    # /super-admin/accounts/abc/edit) a 404 rather than a
    # PG::InvalidTextRepresentation 500.
    def set_account
      @account = Account[params[:id].to_i]

      render_not_found unless @account
    end

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

    def own_account?
      @account.id == current_account.id
    end

    # The account legitimately exists and is legitimately visible; the panel
    # just will not do this. 404 stays reserved for hiding existence.
    def refuse(message)
      redirect_to super_admin_accounts_path, alert: message
    end
  end
end
