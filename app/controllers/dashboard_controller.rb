class DashboardController < ApplicationController
  before_action :authenticate_user!

  def show
    @workspace = current_workspace
    @memberships = current_user.memberships.includes(:workspace).order(:created_at)
  end
end
