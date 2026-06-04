require "test_helper"
require "tmpdir"
require "nodl/providers/gemini_client"

class NodlGeminiClientTest < ActiveSupport::TestCase
  FakeResponse = Struct.new(:code, :body, :headers, keyword_init: true) do
    def [](name)
      headers[name.downcase]
    end
  end

  class RecordingClient < Nodl::Providers::GeminiClient
    attr_reader :requests

    def initialize(responses)
      super(api_key: "test-key")
      @responses = responses
      @requests = []
    end

    protected

    def perform(uri, request)
      requests << { uri: uri, request: request, body: request.body }
      @responses.shift
    end
  end

  test "requires an api key" do
    error = assert_raises(Nodl::ConfigurationError) do
      Nodl::Providers::GeminiClient.new(api_key: "")
    end

    assert_includes error.message, "GEMINI_API_KEY"
  end

  test "uploads files with gemini resumable upload requests" do
    Dir.mktmpdir do |dir|
      file_path = Pathname.new(dir).join("sample.mp3")
      file_path.write("audio bytes")
      client = RecordingClient.new([
        FakeResponse.new(code: "200", body: "{}", headers: { "x-goog-upload-url" => "https://upload.test/session" }),
        FakeResponse.new(code: "200", body: JSON.dump(file: { uri: "files/abc123" }), headers: {})
      ])

      response = client.upload_file(path: file_path, mime_type: "audio/mpeg", display_name: "sample.mp3")

      assert_equal "files/abc123", response.dig("file", "uri")
      assert_equal "/upload/v1beta/files", client.requests.first.fetch(:uri).path
      assert_equal "test-key", client.requests.first.fetch(:request)["x-goog-api-key"]
      assert_equal "resumable", client.requests.first.fetch(:request)["X-Goog-Upload-Protocol"]
      assert_includes client.requests.first.fetch(:body), "sample.mp3"
      assert_equal "upload, finalize", client.requests.second.fetch(:request)["X-Goog-Upload-Command"]
      assert_equal "audio bytes", client.requests.second.fetch(:body)
    end
  end

  test "generates text and extracts candidate text" do
    client = RecordingClient.new([
      FakeResponse.new(
        code: "200",
        body: JSON.dump(candidates: [ { content: { parts: [ { text: "Generated text" } ] } } ]),
        headers: {}
      )
    ])

    text = client.generate_text(
      model: "gemini-3.1-flash-lite",
      parts: [ { text: "Prompt" } ],
      generation_config: { temperature: 0.2 }
    )

    assert_equal "Generated text", text
    assert_equal "/v1beta/models/gemini-3.1-flash-lite:generateContent", client.requests.first.fetch(:uri).path
    body = JSON.parse(client.requests.first.fetch(:body))
    assert_equal "Prompt", body.dig("contents", 0, "parts", 0, "text")
    assert_equal 0.2, body.dig("generation_config", "temperature")
  end

  test "raises clear errors on non-success responses" do
    client = RecordingClient.new([
      FakeResponse.new(code: "500", body: "server error", headers: {})
    ])

    error = assert_raises(Nodl::GeminiError) do
      client.generate_text(model: "gemini-3.1-flash-lite", parts: [ { text: "Prompt" } ])
    end

    assert_includes error.message, "HTTP 500"
  end
end
