class PushSubscriptionsController < ApplicationController
  before_action :authenticate_user!

  def create
    subscription = PushSubscription.find_or_initialize_by(endpoint: subscription_params[:endpoint])
    subscription.assign_attributes(
      subscription_params.merge(user: current_user, user_agent: request.user_agent)
    )

    if subscription.save
      head :created
    else
      render json: { errors: subscription.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    subscription = current_user.push_subscriptions.find_by!(endpoint: params.require(:endpoint))
    subscription.destroy!
    head :no_content
  end

  private

  def subscription_params
    params.require(:push_subscription).permit(:endpoint, :p256dh_key, :auth_key)
  end
end
