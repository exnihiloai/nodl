require "test_helper"
require "tmpdir"
require "nodl/providers/mistral_client"

class NodlMistralClientTest < ActiveSupport::TestCase
  FakeResponse = Struct.new(:code, :body, keyword_init: true)

  class RecordingClient < Nodl::Providers::MistralClient
    attr_reader :requests

    def initialize(responses)
      super(api_key: "test-key")
      @responses = responses
      @requests = []
    end

    protected

    def perform(uri, request)
      requests << { uri: uri, request: request, body_data: request.instance_variable_get(:@body_data) }
      @responses.shift
    end
  end

  test "requires an api key" do
    error = assert_raises(Nodl::ConfigurationError) do
      Nodl::Providers::MistralClient.new(api_key: "")
    end

    assert_includes error.message, "MISTRAL_API_KEY"
  end

  test "constructs multipart transcription request with diarization and timestamps" do
    Dir.mktmpdir do |dir|
      file_path = Pathname.new(dir).join("sample.mp3")
      file_path.write("audio bytes")
      client = RecordingClient.new([
        FakeResponse.new(
          code: "200",
          body: JSON.dump(text: "Hello", segments: [], language: "en", usage: { prompt_audio_seconds: 3.2 })
        )
      ])

      payload = client.transcribe(
        path: file_path,
        model: "voxtral-mini-latest",
        diarize: true,
        timestamp_granularities: %w[segment]
      )

      assert_equal "Hello", payload.fetch("text")
      request = client.requests.first.fetch(:request)
      assert_equal "Bearer test-key", request["Authorization"]
      assert_equal "/v1/audio/transcriptions", client.requests.first.fetch(:uri).path
      field_names = client.requests.first.fetch(:body_data).map(&:first)
      assert_includes field_names, "file"
      assert_includes field_names, "model"
      assert_equal 1, field_names.count("timestamp_granularities")
      assert_equal "segment", client.requests.first.fetch(:body_data).assoc("timestamp_granularities").second
      assert_equal 0, field_names.count("timestamp_granularities[]")
      assert_includes client.requests.first.fetch(:body_data), [ "diarize", "true" ]
    end
  end

  test "surfaces mistral diarization timestamp granularity validation errors" do
    client = RecordingClient.new([
      FakeResponse.new(
        code: "422",
        body: JSON.dump(
          object: "error",
          message: {
            detail: [
              {
                type: "assertion_error",
                loc: [],
                msg: "Assertion failed, When diarize is set to True and streaming is disabled, the timestamp granularity must be set to ['segment'], got ['word']"
              }
            ]
          },
          type: "invalid_request_error",
          raw_status_code: 422
        )
      )
    ])

    error = assert_raises(Nodl::MistralError) do
      client.transcribe(path: Rails.root.join("test", "fixtures", "files", "sample.mp3"), model: "voxtral-mini-latest", diarize: true, timestamp_granularities: %w[word])
    end

    assert_includes error.message, "HTTP 422"
    assert_includes error.message, "must be set to ['segment']"
  end

  test "surfaces mistral timestamp granularity validation errors" do
    client = RecordingClient.new([
      FakeResponse.new(
        code: "422",
        body: JSON.dump(
          object: "error",
          message: {
            detail: [
              {
                type: "too_long",
                loc: [ "timestamp_granularities" ],
                msg: "List should have at most 1 item after validation, not 2"
              }
            ]
          },
          type: "invalid_request_error",
          raw_status_code: 422
        )
      )
    ])

    error = assert_raises(Nodl::MistralError) do
      client.transcribe(path: Rails.root.join("test", "fixtures", "files", "sample.mp3"), model: "voxtral-mini-latest", diarize: true, timestamp_granularities: %w[segment word])
    end

    assert_includes error.message, "HTTP 422"
    assert_includes error.message, "at most 1 item"
  end

  test "raises clear errors on non-success responses" do
    client = RecordingClient.new([
      FakeResponse.new(code: "500", body: "server error")
    ])

    error = assert_raises(Nodl::MistralError) do
      client.transcribe(path: Rails.root.join("test", "fixtures", "files", "sample.mp3"), model: "voxtral-mini-latest", diarize: true, timestamp_granularities: %w[segment])
    end

    assert_includes error.message, "HTTP 500"
  end
end
