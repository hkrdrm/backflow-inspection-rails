# Identity resolution while a super admin is impersonating someone.
#
# Rodauth's session keeps identifying the real operator for the whole
# impersonation — nothing calls `login`, so no remember-me cookie is ever
# written for the target and stopping is always possible. Only
# `current_account` moves, which is why every existing caller of it
# (TenantScoped, require_super_admin, the sidebar) behaves correctly with no
# change of its own.
module Impersonation
  extend ActiveSupport::Concern

  included do
    helper_method :impersonating?
  end

  private

  # The person actually logged in. Authorization for stopping an impersonation
  # must use this, never current_account.
  def true_account
    rodauth.rails_account
  end

  def current_account
    @current_account ||= impersonated_account || true_account
  end

  def impersonating?
    impersonated_account.present?
  end

  def impersonated_account
    return @impersonated_account if defined?(@impersonated_account)

    id = session[:impersonated_account_id]
    @impersonated_account = id && Account[id]
    # Defensive: accounts are never deleted by this app, but a session pointing
    # at a row that is gone must fall back to the real identity rather than
    # 500 on every request.
    clear_impersonation_session if id && @impersonated_account.nil?
    @impersonated_account
  end

  def clear_impersonation_session
    session.delete(:impersonated_account_id)
    session.delete(:impersonation_session_id)
  end
end
