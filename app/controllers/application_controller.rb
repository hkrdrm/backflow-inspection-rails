class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  include Impersonation

  private
  def current_session
		User::Session.find
  end

  def current_user
    @current_user ||= current_session.record
  end

  def current_tenant
    @current_tenant ||= current_account&.tenant
  end

  def authenticate
    rodauth.require_account
  end

  # Renders 404 rather than 403 so the existence of a resource or area is not
  # confirmed to anyone probing for it.
  def render_not_found
    render html: Rails.public_path.join("404.html").read.html_safe,
           status: :not_found,
           layout: false
  end

  helper_method :current_account, :current_tenant
end
