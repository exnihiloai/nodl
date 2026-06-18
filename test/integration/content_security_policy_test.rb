require "test_helper"

class ContentSecurityPolicyTest < ActionDispatch::IntegrationTest
  test "allows external form targets used by oauth and checkout" do
    get login_path

    policy = response.headers.fetch("Content-Security-Policy")
    assert_includes policy, "form-action 'self' https://accounts.google.com https://checkout.stripe.com"
  end
end
