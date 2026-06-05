require "digest"

class SessionsController < ApplicationController
  class CacheUnavailableError < StandardError; end

  rescue_from CacheUnavailableError, with: :handle_cache_unavailable

  LOGIN_ATTEMPT_WINDOW = 10.minutes
  LOGIN_BLOCK_WINDOW = 15.minutes
  MAX_LOGIN_ATTEMPTS = 10

  def new
    redirect_to dashboard_path if current_user
  end

  def create
    email = normalized_email
    remote_ip = request.remote_ip.to_s

    if login_throttled?(email, remote_ip)
      flash.now[:alert] = "Invalid credentials."
      render :new, status: :too_many_requests
      return
    end

    user = User.find_by(email: email)

    if user&.authenticate(login_params[:password]) && user.active?
      reset_session
      session[:user_id] = user.id
      session[:current_workspace_id] = user.workspaces.order("memberships.created_at ASC").pick(:id)
      clear_failed_login_attempts(email, remote_ip)
      user.update(last_login_at: Time.current)
      redirect_to dashboard_path, notice: "Welcome back."
      return
    end

    record_failed_login_attempt(email, remote_ip)
    flash.now[:alert] = "Invalid credentials."
    render :new, status: login_throttled?(email, remote_ip) ? :too_many_requests : :unprocessable_entity
  end

  def destroy
    reset_session
    redirect_to root_path, notice: "You have been signed out."
  end

  private

  def handle_cache_unavailable(exception)
    Rails.logger.error("Authentication failed closed due to cache error: #{exception.message}")
    flash.now[:alert] = "Authentication service is temporarily unavailable. Please try again later."
    render :new, status: :service_unavailable
  end

  def normalized_email
    login_params[:email].to_s.downcase.strip
  end

  def login_params
    params.permit(:email, :password)
  end

  def login_throttled?(email, remote_ip)
    blocked_until = Rails.cache.read(blocked_login_cache_key(email, remote_ip))
    blocked_until.present? && blocked_until > Time.current
  rescue StandardError => e
    raise CacheUnavailableError, "Cache read failed: #{e.message}"
  end

  def record_failed_login_attempt(email, remote_ip)
    key = failed_login_cache_key(email, remote_ip)
    attempts = Rails.cache.read(key).to_i + 1
    Rails.cache.write(key, attempts, expires_in: LOGIN_ATTEMPT_WINDOW)

    return unless attempts >= MAX_LOGIN_ATTEMPTS

    Rails.cache.write(blocked_login_cache_key(email, remote_ip), Time.current + LOGIN_BLOCK_WINDOW, expires_in: LOGIN_BLOCK_WINDOW)
  rescue StandardError => e
    raise CacheUnavailableError, "Cache write failed: #{e.message}"
  end

  def clear_failed_login_attempts(email, remote_ip)
    Rails.cache.delete(failed_login_cache_key(email, remote_ip))
    Rails.cache.delete(blocked_login_cache_key(email, remote_ip))
  rescue StandardError => e
    raise CacheUnavailableError, "Cache delete failed: #{e.message}"
  end

  def failed_login_cache_key(email, remote_ip)
    "auth:failed_login:#{Digest::SHA256.hexdigest("#{email}|#{remote_ip}")}"
  end

  def blocked_login_cache_key(email, remote_ip)
    "auth:blocked_login:#{Digest::SHA256.hexdigest("#{email}|#{remote_ip}")}"
  end
end
