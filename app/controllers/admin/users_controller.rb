module Admin
  class UsersController < ApplicationController
    before_action :authenticate_user!
    before_action :require_admin!
    before_action :set_managed_user, only: %i[show update_email update_role update_password update_integrity_sealing update_usage generate_password deactivate reactivate]

    def index
      @users = User.includes(:memberships, :workspaces).order(created_at: :desc)
    end

    def show
      load_user_detail
    end

    def new
      @user = User.new
    end

    def create
      email = params[:email].to_s.strip.downcase
      role = params[:role].presence || "user"
      raw_password = params[:password].to_s
      generated_password = raw_password.presence || generate_complex_password
      normalized_role = normalize_role(role)

      if normalized_role.blank?
        render_create_error(t("admin.flash.invalid_role"))
        return
      end

      user = nil

      ActiveRecord::Base.transaction do
        user = User.create!(
          email:,
          password: generated_password,
          password_confirmation: generated_password,
          role: normalized_role,
          preferred_language: "en"
        )

        workspace = Workspace.create!(
          name: default_workspace_name(user),
          usage_limits: { scans: 1000, storage_mb: 1024 },
          usage_consumption: { scans: 0, storage_mb: 0 }
        )

        Membership.create!(user:, workspace:, role: :owner)
        audit!(user, "create_user", nil, { email: user.email, role: user.role, workspace_id: workspace.id })
      end

      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "create_result",
            partial: "admin/users/create_result",
            locals: {
              managed_user: user,
              generated_password: raw_password.present? ? nil : generated_password,
              error_message: nil
            }
          )
        end
        format.html { redirect_to admin_user_path(user), notice: t("admin.flash.user_created") }
      end
    rescue ActiveRecord::RecordInvalid => e
      render_create_error(e.record.errors.full_messages.to_sentence, email:, role:)
    end

    def update_email
      before_state = { email: @managed_user.email }

      if @managed_user.update(email: params[:email].to_s.strip.downcase)
        audit!(@managed_user, "update_email", before_state, { email: @managed_user.email })
        render_email_section(notice: t("admin.flash.email_updated"))
      else
        render_email_section(error: @managed_user.errors.full_messages.to_sentence, status: :unprocessable_entity)
      end
    end

    def update_role
      before_state = { role: @managed_user.role }
      normalized_role = normalize_role(params[:role])

      if normalized_role.blank?
        render_role_section(error: t("admin.flash.invalid_role"), status: :unprocessable_entity)
        return
      end

      if @managed_user.update(role: normalized_role)
        audit!(@managed_user, "update_role", before_state, { role: @managed_user.role })
        render_role_section(notice: t("admin.flash.role_updated"))
      else
        render_role_section(error: @managed_user.errors.full_messages.to_sentence, status: :unprocessable_entity)
      end
    end

    def update_password
      password = params[:password].to_s

      if password.blank?
        render_password_section(error: t("admin.flash.password_blank"), status: :unprocessable_entity)
        return
      end

      if @managed_user.update(password: password, password_confirmation: password)
        audit!(@managed_user, "update_password", nil, { updated: true })
        render_password_section(notice: t("admin.flash.password_updated"))
      else
        render_password_section(error: @managed_user.errors.full_messages_for(:password).to_sentence, status: :unprocessable_entity)
      end
    end

    def update_integrity_sealing
      enabled = ActiveModel::Type::Boolean.new.cast(params[:integrity_sealing_enabled])
      before_state = { integrity_sealing_enabled: @managed_user.integrity_sealing_enabled }

      if @managed_user.update(integrity_sealing_enabled: enabled)
        audit!(@managed_user, "update_integrity_sealing", before_state, { integrity_sealing_enabled: @managed_user.integrity_sealing_enabled })
        render_integrity_sealing_section(notice: t("admin.flash.integrity_sealing_updated"))
      else
        render_integrity_sealing_section(error: @managed_user.errors.full_messages.to_sentence, status: :unprocessable_entity)
      end
    end

    def generate_password
      generated_password = generate_complex_password

      if @managed_user.update(password: generated_password, password_confirmation: generated_password)
        audit!(@managed_user, "generate_password", nil, { generated: true })
        render_password_section(notice: t("admin.flash.temp_password_generated"), generated_password:)
      else
        render_password_section(error: @managed_user.errors.full_messages_for(:password).to_sentence, status: :unprocessable_entity)
      end
    end

    def deactivate
      before_state = { active: @managed_user.active }

      if @managed_user.update(active: false)
        audit!(@managed_user, "deactivate", before_state, { active: false })
        render_lifecycle_section(notice: t("admin.flash.user_deactivated"))
      else
        render_lifecycle_section(error: @managed_user.errors.full_messages.to_sentence, status: :unprocessable_entity)
      end
    end

    def reactivate
      before_state = { active: @managed_user.active }

      if @managed_user.update(active: true)
        audit!(@managed_user, "reactivate", before_state, { active: true })
        render_lifecycle_section(notice: t("admin.flash.user_reactivated"))
      else
        render_lifecycle_section(error: @managed_user.errors.full_messages.to_sentence, status: :unprocessable_entity)
      end
    end

    def update_usage
      workspace = primary_workspace_for(@managed_user)

      if workspace.blank?
        render_usage_section(error: t("admin.flash.no_workspace"), status: :unprocessable_entity)
        return
      end

      scans = params[:scans].to_i
      storage_mb = params[:storage_mb].to_i
      scans = 0 if scans.negative?
      storage_mb = 0 if storage_mb.negative?

      before_state = { usage_limits: workspace.usage_limits }
      after_limits = workspace.usage_limits.merge("scans" => scans, "storage_mb" => storage_mb)

      if workspace.update(usage_limits: after_limits)
        audit!(@managed_user, "update_usage_limits", before_state, { usage_limits: after_limits })
        render_usage_section(notice: t("admin.flash.usage_updated"))
      else
        render_usage_section(error: workspace.errors.full_messages.to_sentence, status: :unprocessable_entity)
      end
    end

    private

    def set_managed_user
      @managed_user = User.find(params[:id])
      load_user_detail
    end

    def load_user_detail
      @workspace = primary_workspace_for(@managed_user)
      @audit_events = @managed_user.admin_audit_events.recent_first.limit(25)
    end

    def primary_workspace_for(user)
      user.workspaces.order("memberships.created_at ASC").first
    end

    def audit!(target_user, action, before_state, after_state)
      AdminAuditEvent.create!(
        user: target_user,
        acting_admin: current_user,
        action:,
        before_state:,
        after_state:
      )
    end

    def default_workspace_name(user)
      "#{user.email.split("@").first.titleize} Workspace"
    end

    def email_section_id
      "email_section"
    end

    def role_section_id
      "role_section"
    end

    def password_section_id
      "password_section"
    end

    def integrity_sealing_section_id
      "integrity_sealing_section"
    end

    def lifecycle_section_id
      "lifecycle_section"
    end

    def usage_section_id
      "usage_section"
    end

    def render_email_section(notice: nil, error: nil, status: :ok)
      render_section(email_section_id, "admin/users/email_section", { managed_user: @managed_user, notice:, error: }, status)
    end

    def render_role_section(notice: nil, error: nil, status: :ok)
      render_section(role_section_id, "admin/users/role_section", { managed_user: @managed_user, notice:, error: }, status)
    end

    def render_password_section(notice: nil, error: nil, generated_password: nil, status: :ok)
      render_section(password_section_id, "admin/users/password_section", { managed_user: @managed_user, notice:, error:, generated_password: }, status)
    end

    def render_integrity_sealing_section(notice: nil, error: nil, status: :ok)
      render_section(integrity_sealing_section_id, "admin/users/integrity_sealing_section", { managed_user: @managed_user, notice:, error: }, status)
    end

    def render_lifecycle_section(notice: nil, error: nil, status: :ok)
      render_section(lifecycle_section_id, "admin/users/lifecycle_section", { managed_user: @managed_user, notice:, error: }, status)
    end

    def render_usage_section(notice: nil, error: nil, status: :ok)
      render_section(usage_section_id, "admin/users/usage_section", { managed_user: @managed_user, workspace: @workspace, notice:, error: }, status)
    end

    def render_section(section_id, partial, locals, status)
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(section_id, partial:, locals:), status:
        end
        format.html do
          flash_key = status == :ok ? :notice : :alert
          flash[flash_key] = locals[:notice] || locals[:error]
          redirect_to admin_user_path(@managed_user)
        end
      end
    end

    def render_create_error(message, email: nil, role: nil)
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "create_result",
            partial: "admin/users/create_result",
            locals: {
              managed_user: nil,
              generated_password: nil,
              error_message: message
            }
          ), status: :unprocessable_entity
        end
        format.html do
          flash.now[:alert] = message
          @user = User.new(email:, role:)
          render :new, status: :unprocessable_entity
        end
      end
    end

    def normalize_role(raw_role)
      role = raw_role.to_s
      User.roles.key?(role) ? role : nil
    end

    def generate_complex_password
      loop do
        pass = SecureRandom.base58(15)
        return pass if pass.match?(/[A-Z]/) && pass.match?(/[a-z]/) && pass.match?(/\d/)
      end
    end
  end
end
