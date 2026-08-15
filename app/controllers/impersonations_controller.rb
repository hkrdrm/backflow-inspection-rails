# Ending an impersonation. Lives outside the SuperAdmin namespace on purpose:
# while impersonating, current_account is the target, so anything guarded by
# require_super_admin would 404 the operator with no way back.
class ImpersonationsController < ApplicationController
  before_action :authenticate

  def destroy
    # Authorized against the real identity, which is precisely what the
    # session-swap design preserves. The session key alone is enough: only
    # someone who passed the super admin gate to start could have set it, and
    # the Rails session is signed, so the exit survives that flag being revoked
    # mid-impersonation. An account that never started one has neither and 404s.
    return render_not_found unless session[:impersonation_session_id] || true_account&.super_admin?

    if (id = session[:impersonation_session_id])
      ImpersonationSession.where(id: id, ended_at: nil).update(ended_at: Time.current)
    end

    clear_impersonation_session

    redirect_to super_admin_accounts_path, notice: "Impersonation ended."
  end
end
