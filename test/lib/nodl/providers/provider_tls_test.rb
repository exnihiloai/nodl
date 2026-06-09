require "test_helper"
require "nodl/providers/gemini_client"
require "nodl/providers/mistral_client"
require "nodl/providers/mistral_realtime_client"

# Guards that all subprocessor traffic carrying user data uses encrypted transport.
# A regression here (e.g. an http:// endpoint) would send transcripts/audio in clear.
class ProviderTlsTest < ActiveSupport::TestCase
  test "REST clients only enable the connection over TLS for https URIs" do
    [ Nodl::Providers::GeminiClient, Nodl::Providers::MistralClient ].each do |klass|
      client = klass.new(api_key: "test-key")

      assert capture_use_ssl(client, "https://api.example.com/v1/thing"),
        "#{klass}#perform must use TLS for https endpoints"
      refute capture_use_ssl(client, "http://api.example.com/v1/thing"),
        "#{klass}#perform must not silently downgrade to plaintext http"
    end
  end

  test "REST client API hosts are real provider endpoints" do
    assert_equal "generativelanguage.googleapis.com", Nodl::Providers::GeminiClient::API_HOST
    assert_equal "api.mistral.ai", Nodl::Providers::MistralClient::API_HOST
  end

  test "realtime transcription uses a secure websocket" do
    client = Nodl::Providers::MistralRealtimeClient.new(api_key: "test-key")

    assert client.send(:realtime_url).start_with?("wss://"),
      "realtime transcription must use wss:// (encrypted websocket)"
  end

  private

  # Calls the client's #perform with the given URI and returns the use_ssl flag it
  # passed to Net::HTTP.start (the bytes never leave the process).
  def capture_use_ssl(client, url)
    captured = nil
    fake_response = Struct.new(:code, :body).new("200", "{}")
    Net::HTTP.stubs(:start).with do |*args, **kwargs|
      captured = kwargs.fetch(:use_ssl) { args.last.is_a?(Hash) ? args.last[:use_ssl] : nil }
      true
    end.returns(fake_response)

    client.send(:perform, URI(url), Net::HTTP::Get.new(URI(url)))
    captured
  ensure
    Net::HTTP.unstub(:start)
  end
end
