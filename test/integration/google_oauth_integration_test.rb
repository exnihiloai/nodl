require "test_helper"

class GoogleOauthIntegrationTest < ActionDispatch::IntegrationTest
  test "google callback creates a user workspace and session" do
    with_google_auth(email: "new-google@example.test", uid: "google-new-1") do
      assert_difference "User.count", 1 do
        assert_difference "Workspace.count", 1 do
          perform_google_auth
        end
      end
    end

    user = User.find_by!(email: "new-google@example.test")
    assert_equal "google_oauth2", user.provider
    assert_equal "google-new-1", user.uid
    assert_equal "Google Tester", user.name
    assert_equal "https://google.example/avatar.png", user.avatar_url
    assert_predicate user.workspaces, :exists?
    assert_redirected_to dashboard_path

    follow_redirect!
    assert_response :success
  end

  test "google callback links an existing user by verified email" do
    user = create_user_with_workspace(email: "existing-google@example.test")

    with_google_auth(email: user.email, uid: "google-existing-1") do
      assert_no_difference "User.count" do
        perform_google_auth
      end
    end

    user.reload
    assert_equal "google_oauth2", user.provider
    assert_equal "google-existing-1", user.uid
    assert_redirected_to dashboard_path
  end

  test "google callback rejects unverified email" do
    with_google_auth(email: "unverified-google@example.test", uid: "google-unverified-1", verified: false) do
      assert_no_difference "User.count" do
        perform_google_auth
      end
    end

    assert_redirected_to login_path
    follow_redirect!
    assert_includes response.body, "Google did not confirm a verified email address."
  end

  private

  def setup
    super
    OmniAuth.config.test_mode = true
  end

  def teardown
    OmniAuth.config.mock_auth[:google_oauth2] = nil
    OmniAuth.config.test_mode = false
    super
  end

  def with_google_auth(email:, uid:, verified: true)
    previous_auth = Rails.application.env_config["omniauth.auth"]
    auth_hash = OmniAuth::AuthHash.new(
      provider: "google_oauth2",
      uid: uid,
      info: {
        email: email,
        name: "Google Tester",
        image: "https://google.example/avatar.png"
      },
      extra: {
        id_info: {
          email_verified: verified
        }
      }
    )
    Rails.application.env_config["omniauth.auth"] = auth_hash
    OmniAuth.config.mock_auth[:google_oauth2] = auth_hash

    yield
  ensure
    Rails.application.env_config["omniauth.auth"] = previous_auth
    OmniAuth.config.mock_auth[:google_oauth2] = nil
  end

  def perform_google_auth
    if omniauth_middleware_configured?
      post user_google_oauth2_omniauth_authorize_path
      follow_redirect! if response.redirect? && response.location.include?("/users/auth/google_oauth2/callback")
    else
      get "/users/auth/google_oauth2/callback"
    end
  end

  def omniauth_middleware_configured?
    Rails.application.middleware.any? { |middleware| middleware.klass == OmniAuth::Builder }
  end
end
