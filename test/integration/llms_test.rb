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

  test "homepage responds with RFC 8288 Link headers for agent discovery" do
    get root_path

    link_header = response.headers["Link"]
    assert_not_nil link_header, "Link header must be present"
    assert_includes link_header, "</llms.txt>; rel=\"describedby\""
    assert_includes link_header, "</llms-full.txt>; rel=\"describedby\""
    assert_includes link_header, "rel=\"service-doc\""
  end

  test "all pages carry the agent discovery Link header" do
    get login_path

    assert_not_nil response.headers["Link"]
    assert_includes response.headers["Link"], "describedby"
  end
end
