class SettingsController < ApplicationController
  before_action :authenticate_user!

  def show
    @user = current_user
  end

  def update
    @user = current_user

    if @user.update(settings_params)
      redirect_to settings_path, notice: t("settings.flash.updated")
    else
      flash.now[:alert] = t("settings.flash.invalid")
      render :show, status: :unprocessable_entity
    end
  end

  private

  def settings_params
    permitted = params.require(:user).permit(
      :daily_reminder_enabled,
      :daily_reminder_at,
      :daily_reminder_message,
      :time_zone
    )

    permitted[:daily_reminder_enabled] = ActiveModel::Type::Boolean.new.cast(permitted[:daily_reminder_enabled])

    unless permitted[:daily_reminder_enabled]
      permitted[:daily_reminder_message] = @user.daily_reminder_message
    end

    permitted
  end
end
