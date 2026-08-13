module SuperAdmin
  class BaseController < ApplicationController
    layout "app"

    # Order matters: authenticate first so an anonymous visitor is sent to
    # login rather than shown a misleading 404.
    before_action :authenticate
    before_action :require_super_admin

    private

    # Renders 404 rather than 403 so the existence of the admin area is not
    # confirmed to anyone probing for it.
    def require_super_admin
      render_not_found unless current_account&.super_admin?
    end

    def render_not_found
      render html: Rails.public_path.join("404.html").read.html_safe,
             status: :not_found,
             layout: false
    end
  end
end
