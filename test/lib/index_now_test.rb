require "test_helper"

class IndexNowTest < ActiveSupport::TestCase
  setup do
    @root = Pathname.new(Dir.mktmpdir)
  end

  teardown do
    FileUtils.rm_rf(@root)
  end

  test "discovers a key file whose name matches its contents" do
    @root.join("abc123def4567890.txt").write("abc123def4567890")

    key, location = IndexNow.key(host: "nodl.now", root: @root)

    assert_equal "abc123def4567890", key
    assert_equal "https://nodl.now/abc123def4567890.txt", location
  end

  test "ignores text files that are not keys" do
    @root.join("robots-notes.txt").write("nothing to see")
    @root.join("abc123def4567890.txt").write("abc123def4567890")

    key, = IndexNow.key(host: "nodl.now", root: @root)

    assert_equal "abc123def4567890", key
  end

  test "rejects a key file whose contents do not match its name" do
    # A copied or half-edited key file would otherwise authenticate as valid
    # here and then fail remotely with an opaque 403.
    @root.join("abc123def4567890.txt").write("something-else")

    assert_raises(IndexNow::MissingKeyError) { IndexNow.key(host: "nodl.now", root: @root) }
  end

  test "raises a helpful error when no key file exists" do
    error = assert_raises(IndexNow::MissingKeyError) { IndexNow.key(host: "nodl.now", root: @root) }

    assert_match(/openssl rand -hex 16/, error.message)
  end

  test "payload carries host, key, key location and urls" do
    payload = IndexNow.payload(
      host: "nodl.now",
      urls: [ "https://nodl.now/a", "https://nodl.now/b" ],
      key: "abc123def4567890",
      key_location: "https://nodl.now/abc123def4567890.txt"
    )

    assert_equal "nodl.now", payload[:host]
    assert_equal "abc123def4567890", payload[:key]
    assert_equal "https://nodl.now/abc123def4567890.txt", payload[:keyLocation]
    assert_equal 2, payload[:urlList].size
  end

  test "treats 200 and 202 as success and everything else as failure" do
    assert IndexNow.success?(IndexNow::Result.new(code: "200", message: "OK", submitted: 1))
    assert IndexNow.success?(IndexNow::Result.new(code: "202", message: "Accepted", submitted: 1))
    assert_not IndexNow.success?(IndexNow::Result.new(code: "403", message: "Forbidden", submitted: 1))
  end

  test "refuses an empty submission" do
    assert_raises(ArgumentError) { IndexNow.submit([]) }
  end

  test "the live key file in public/ is well formed" do
    key, location = IndexNow.key(host: "nodl.now")

    assert_match(/\A[a-f0-9]{8,128}\z/, key)
    assert_equal "https://nodl.now/#{key}.txt", location
  end
end
