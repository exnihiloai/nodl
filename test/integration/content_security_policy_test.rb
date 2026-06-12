require "test_helper"

class ContentSecurityPolicyTest < ActionDispatch::IntegrationTest
  test "allows google oauth request phase redirect target in form action" do
    get login_path

    policy = response.headers.fetch("Content-Security-Policy")
    assert_includes policy, "form-action 'self' https://accounts.google.com"
  end
end
