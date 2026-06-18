module Admin::UserEntitlementManagement
  extend ActiveSupport::Concern

  def update_entitlement
    workspace = primary_workspace_for(@managed_user)

    if workspace.blank?
      render_entitlement_section(error: t("admin.flash.no_workspace"), status: :unprocessable_entity)
      return
    end

    reason = params[:reason].to_s.strip
    if reason.blank?
      render_entitlement_section(error: t("admin.flash.entitlement_reason_required"), status: :unprocessable_entity)
      return
    end

    before_state = entitlement_state(workspace.current_entitlement)
    entitlement = WorkspaceEntitlementGrant.grant!(
      workspace:,
      plan_code: "manual",
      source: "manual",
      status: "active",
      actor: current_user,
      reason:
    )

    audit!(@managed_user, "grant_private_access", before_state, entitlement_state(entitlement).merge(reason:))
    render_entitlement_section(notice: t("admin.flash.private_access_granted"))
  end

  private

  def entitlement_section_id
    "entitlement_section"
  end

  def render_entitlement_section(notice: nil, error: nil, status: :ok)
    render_section(entitlement_section_id, "admin/users/entitlement_section", { managed_user: @managed_user, workspace: @workspace, notice:, error: }, status)
  end

  def entitlement_state(entitlement)
    return {} unless entitlement

    {
      plan_code: entitlement.plan_code,
      display_name: entitlement.display_name,
      source: entitlement.source,
      status: entitlement.status,
      plan_version: entitlement.billing_plan_version.version_key
    }
  end
end
