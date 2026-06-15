class SettingsController < ApplicationController
  before_action :authenticate_user!

  def show
    @user = current_user
  end

  def update
    @user = current_user

    if enabling_daily_reminder? && !WebPushConfig.configured?
      flash.now[:alert] = t("settings.daily_reminder.push_not_configured")
      render :show, status: :unprocessable_entity
      return
    end

    if @user.update(settings_params)
      clear_daily_reminder_last_sent_if_schedule_changed
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

  def enabling_daily_reminder?
    ActiveModel::Type::Boolean.new.cast(settings_params[:daily_reminder_enabled])
  end

  def clear_daily_reminder_last_sent_if_schedule_changed
    return unless @user.daily_reminder_enabled?

    schedule_changed = @user.saved_change_to_daily_reminder_at? ||
      @user.saved_change_to_time_zone? ||
      (@user.saved_change_to_daily_reminder_enabled? && @user.daily_reminder_enabled?)

    return unless schedule_changed

    @user.update_column(:daily_reminder_last_sent_on, nil)
  end
end
