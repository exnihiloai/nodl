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
        password_confirmation: @form["password_confirm"],
        preferred_language: "en"
      )

      workspace = Workspace.create!(
        name: default_workspace_name(user.email),
        slug: SecureRandom.alphanumeric(10).downcase,
        usage_limits: { scans: 1000, storage_mb: 1024 },
        usage_consumption: { scans: 0, storage_mb: 0 }
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
      "email_confirm" => "",
      "password" => "",
      "password_confirm" => "",
      "accept_legal" => "0"
    }
  end

  def registration_params
    params.permit(:email, :email_confirm, :password, :password_confirm, :accept_legal)
  end

  def validate_registration(form)
    errors = []

    email = form.fetch("email", "").to_s.strip.downcase
    email_confirm = form.fetch("email_confirm", "").to_s.strip.downcase
    password = form.fetch("password", "").to_s
    password_confirm = form.fetch("password_confirm", "").to_s

    errors << t("registrations.errors.email_mismatch") if email != email_confirm
    errors << t("registrations.errors.password_mismatch") if password != password_confirm
    errors << t("registrations.errors.email_taken") if User.exists?(email:)
    errors << t("registrations.errors.legal_not_accepted") if legal_consent_required? && form["accept_legal"] != "1"

    # Validate password complexity via central User model validations
    temp_user = User.new(password: password, password_confirmation: password_confirm)
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
