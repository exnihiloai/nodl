require "test_helper"

class LlmsIntegrationTest < ActionDispatch::IntegrationTest
  test "llms.txt is served as plain text with the Nodl summary" do
    get llms_path

    assert_response :success
    assert_equal "text/plain; charset=utf-8", response.content_type
    assert_includes response.body, "# Nodl"
    assert_includes response.body, "https://nodl.now"
  end

  test "llms-full.txt is served as plain text" do
    get llms_full_path

    assert_response :success
    assert_equal "text/plain; charset=utf-8", response.content_type
    assert_includes response.body, "# Nodl"
  end

  test "html pages advertise llms.txt via an alternate link in the head" do
    get login_path

    assert_response :success
    assert_includes response.body, "rel=\"alternate\""
    assert_includes response.body, "/llms.txt"
  end
end
