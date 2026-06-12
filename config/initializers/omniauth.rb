OmniAuth.config.allowed_request_methods = %i[post]
OmniAuth.config.path_prefix = "/users/auth"

google_client_id = ENV["GOOGLE_CLIENT_ID"].presence
google_client_secret = ENV["GOOGLE_CLIENT_SECRET"].presence

if google_client_id && google_client_secret
  Rails.application.config.middleware.use OmniAuth::Builder do
    provider :google_oauth2,
             google_client_id,
             google_client_secret,
             scope: "openid email profile",
             prompt: "select_account"
  end
end
