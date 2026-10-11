class RegistrationsController < ApplicationController
  def new
    @form = registration_defaults
  end

  def create
    @form = registration_defaults.merge(registration_params.to_h)
    errors = validate_registration(@form)

    if errors.any?
      flash.now[:alert] = errors.join(" ")
      render :new, status: :unprocessable_entity
      return
    end

    ActiveRecord::Base.transaction do
      user = User.create!(
        email: @form["email"],
        password: @form["password"],
        password_confirmation: @form["password"],
        preferred_language: current_locale.to_s,
        last_login_at: Time.current
      )

      workspace = Workspace.create!(
        name: default_workspace_name(user.email),
        slug: SecureRandom.alphanumeric(10).downcase
      )

      Membership.create!(user:, workspace:, role: :owner)

      LegalConsent.record_for(user, request:)

      session[:user_id] = user.id
      session[:current_workspace_id] = workspace.id

      ActiveSupport::Notifications.instrument("nodl.user.registered", user: user)
    end

    redirect_to dashboard_path, notice: t("flash.registrations.created")
  rescue ActiveRecord::RecordInvalid => e
    flash.now[:alert] = e.record.errors.full_messages.join(" ")
    render :new, status: :unprocessable_entity
  end

  private

  def registration_defaults
    {
      "email" => "",
      "password" => "",
      "accept_legal" => "0"
    }
  end

  def registration_params
    params.permit(:email, :password, :accept_legal)
  end

  def validate_registration(form)
    errors = []

    email = form.fetch("email", "").to_s.strip.downcase
    password = form.fetch("password", "").to_s

    errors << t("registrations.errors.email_taken") if User.exists?(email:)
    errors << t("registrations.errors.legal_not_accepted") if legal_consent_required? && form["accept_legal"] != "1"

    # Validate password complexity via central User model validations
    temp_user = User.new(password: password, password_confirmation: password)
    unless temp_user.valid?
      temp_user.errors.full_messages_for(:password).each do |msg|
        errors << msg
      end
    end

    errors
  end

  def default_workspace_name(email)
    prefix = email.split("@").first
    "#{prefix.titleize} Workspace"
  end
end
