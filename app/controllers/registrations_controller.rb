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

      session[:user_id] = user.id
      session[:current_workspace_id] = workspace.id
    end

    redirect_to dashboard_path, notice: "Account created successfully."
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
      "password_confirm" => ""
    }
  end

  def registration_params
    params.permit(:email, :email_confirm, :password, :password_confirm)
  end

  def validate_registration(form)
    errors = []

    email = form.fetch("email", "").to_s.strip.downcase
    email_confirm = form.fetch("email_confirm", "").to_s.strip.downcase
    password = form.fetch("password", "").to_s
    password_confirm = form.fetch("password_confirm", "").to_s

    errors << "Email and confirmation must match." if email != email_confirm
    errors << "Passwords must match." if password != password_confirm
    errors << "This email is already registered." if User.exists?(email:)

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
