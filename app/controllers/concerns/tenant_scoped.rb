# Shared behaviour for every tenant-facing controller: authenticate, then
# require a tenant. Accounts without one (platform super admins) get a 404
# rather than a 403, matching how the super admin area hides itself.
#
# Controllers including this must reach data through `current_tenant`, never
# through `Model.all` — the whole point is that a cross-tenant leak should
# require ignoring the scope rather than forgetting a join.
module TenantScoped
  extend ActiveSupport::Concern

  included do
    layout "app"

    before_action :authenticate
    before_action :require_tenant
  end

  private

  def require_tenant
    render_not_found unless current_tenant
  end
end
