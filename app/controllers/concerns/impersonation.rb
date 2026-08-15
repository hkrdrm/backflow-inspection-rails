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

    # Snapshotted before the action runs so that starting an impersonation is
    # not itself logged as something the target did — at snapshot time the
    # operator is still themselves.
    before_action :snapshot_impersonation
    around_action :audit_impersonated_write
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

  def snapshot_impersonation
    @impersonation_session_id = session[:impersonation_session_id]
  end

  # Around rather than after, because an after-type callback is skipped when the
  # action raises. Nothing wraps a controller action in a transaction here —
  # this app is Sequel, not Active Record — so a save that commits before a
  # later line blows up is a permanent write, and skipping the callback would
  # leave exactly that write untraced. The ensure deliberately does not rescue:
  # the action's exception must still reach the error handling above.
  def audit_impersonated_write
    yield
  ensure
    record_impersonated_write
  end

  # Split out of the ensure above so the guards can stay guard clauses: a bare
  # `return` inside an ensure block discards the exception on its way past,
  # which would turn this audit trail into an exception swallower.
  def record_impersonated_write
    return if @impersonation_session_id.nil?
    return if request.get? || request.head?

    ImpersonationEvent.create(
      impersonation_session_id: @impersonation_session_id,
      request_method: request.request_method,
      path: request.path,
      controller_action: "#{controller_path}##{action_name}"
    )
  end
end
