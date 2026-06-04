module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user, :current_workspace

    def connect
      self.current_user = find_verified_user
      self.current_workspace = find_current_workspace
    end

    private

    def find_verified_user
      user = User.active_only.find_by(id: request.session[:user_id])
      user || reject_unauthorized_connection
    end

    def find_current_workspace
      workspace = current_user.workspaces.find_by(id: request.session[:current_workspace_id])
      workspace || current_user.workspaces.order("memberships.created_at ASC").first || reject_unauthorized_connection
    end
  end
end
