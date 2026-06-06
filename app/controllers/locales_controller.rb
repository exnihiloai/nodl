class LocalesController < ApplicationController
  # Persists the user's language choice in the session and, for signed-in users,
  # on their account so the preference survives across devices and sessions.
  def update
    locale = params[:locale].to_s

    if supported_locale?(locale)
      session[:locale] = locale
      current_user&.update(preferred_language: locale)
    end

    redirect_back fallback_location: root_path, status: :see_other
  end
end
