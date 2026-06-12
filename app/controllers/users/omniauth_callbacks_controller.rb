module Users
  class OmniauthCallbacksController < ApplicationController
    def google_oauth2
      auth = request.env["omniauth.auth"]

      unless verified_google_email?(auth)
        redirect_to login_path, alert: t("flash.oauth.google_unverified")
        return
      end

      user = User.from_google_oauth!(auth)

      unless user.active?
        redirect_to login_path, alert: t("flash.sessions.invalid_credentials")
        return
      end

      reset_session
      session[:user_id] = user.id
      session[:current_workspace_id] = user.workspaces.order("memberships.created_at ASC").pick(:id)
      user.update(last_login_at: Time.current)
      LegalConsent.record_for(user, request:) if user.oauth_new_user
      ActiveSupport::Notifications.instrument("nodl.user.logged_in", user: user)

      redirect_to dashboard_path, notice: t("flash.sessions.welcome_back")
    rescue ActiveRecord::RecordInvalid, KeyError => e
      Rails.logger.warn("Google OAuth login failed: #{e.class}: #{e.message}")
      redirect_to login_path, alert: t("flash.oauth.google_failed")
    end

    def failure
      error = request.env["omniauth.error"]
      Rails.logger.warn("Google OAuth failure: #{oauth_failure_log_line(error)}")
      OauthTelemetry.instrument_config_failure(reason: "omniauth_failure", request:, error:)
      redirect_to login_path, alert: t("flash.oauth.google_failed")
    end

    def passthru
      OauthTelemetry.instrument_config_failure(reason: "not_configured", request:, force: true)
      redirect_to login_path, alert: t("flash.oauth.google_not_configured")
    end

    private

    def oauth_failure_log_line(error)
      type = request.env["omniauth.error.type"]
      return "type=#{type}" if error.nil?

      [ error.class.name, type, error.message ].compact.join(" — ")
    end

    def verified_google_email?(auth)
      email = auth&.dig("info", "email").presence
      verified = auth&.dig("extra", "id_info", "email_verified")

      email.present? && ActiveModel::Type::Boolean.new.cast(verified)
    end
  end
end
