require "test_helper"
require "base64"
require "nodl/integrity/recording_integrity_service"
require "nodl/integrity/tsa_client"

class RecordingIntegrityServiceTest < ActiveSupport::TestCase
  class FakeTsaClient
    attr_reader :calls

    def initialize(result)
      @result = result
      @calls = 0
    end

    def seal_digest(digest:, hash_algorithm:)
      @calls += 1
      @digest = digest
      @hash_algorithm = hash_algorithm
      result
    end

    private

    attr_reader :result
  end

  test "seal_blob hashes exact original bytes and stores pending config without TSA URL" do
    user = create_user_with_workspace
    recording_session = user.workspaces.first.recording_sessions.create!(
      creator: user,
      title: "Integrity",
      transformer_handle: "default"
    ) { |session| attach_sample_audio(session) }
    result = pending_config_result
    client = FakeTsaClient.new(result)

    seal = Nodl::Integrity::RecordingIntegrityService.seal_blob(recording_session.original_audio.blob, tsa_client: client)

    expected = Digest::SHA256.hexdigest(File.binread(Rails.root.join("test", "fixtures", "files", "sample.mp3")))
    assert_equal expected, seal.hash_sha256
    assert_equal RecordingIntegrityRecord::HASH_ALGORITHM_SHA256, seal.hash_algorithm
    assert_equal RecordingIntegrityRecord::STATUS_PENDING_CONFIG, seal.tsa_status
    assert_equal 1, client.calls
  end

  test "upsert creates and updates one integrity record" do
    user = create_user_with_workspace
    recording_session = user.workspaces.first.recording_sessions.create!(
      creator: user,
      title: "Integrity",
      transformer_handle: "default"
    ) { |session| attach_sample_audio(session) }

    assert_difference -> { RecordingIntegrityRecord.count }, 1 do
      Nodl::Integrity::RecordingIntegrityService.upsert!(recording_session, seal_result(hash: "a" * 64, status: RecordingIntegrityRecord::STATUS_FAILED))
    end

    assert_no_difference -> { RecordingIntegrityRecord.count } do
      Nodl::Integrity::RecordingIntegrityService.upsert!(recording_session, seal_result(hash: "b" * 64, status: RecordingIntegrityRecord::STATUS_SEALED, proof: Base64.strict_encode64("proof")))
    end
    assert_equal "b" * 64, recording_session.reload.integrity_record.hash_sha256
    assert_predicate recording_session.integrity_record, :sealed?
  end

  test "certificate payload reports whether bundled audio matches stored hash" do
    user = create_user_with_workspace
    recording_session = user.workspaces.first.recording_sessions.create!(
      creator: user,
      title: "Certificate",
      transformer_handle: "default"
    ) { |session| attach_sample_audio(session) }
    audio = recording_session.original_audio.download
    Nodl::Integrity::RecordingIntegrityService.upsert!(
      recording_session,
      seal_result(hash: Digest::SHA256.hexdigest(audio), status: RecordingIntegrityRecord::STATUS_SEALED, proof: Base64.strict_encode64("proof"))
    )

    payload = Nodl::Integrity::RecordingIntegrityService.certificate_payload(recording_session.reload, audio_bytes: audio)
    mismatch_payload = Nodl::Integrity::RecordingIntegrityService.certificate_payload(recording_session, audio_bytes: "changed")

    assert_equal true, payload[:integrity_hash_matches_exported_file]
    assert_equal false, mismatch_payload[:integrity_hash_matches_exported_file]
    assert_equal recording_session.original_audio_download_filename, payload[:original_filename]
  end

  test "tsa client returns sealed proof and retries transient network errors" do
    request_count = 0
    response = Struct.new(:code, :body, :headers) do
      def [](key)
        headers[key]
      end
    end.new("200", granted_rfc3161_response, { "Date" => "Fri, 20 Mar 2026 10:00:00 GMT" })
    client = Nodl::Integrity::TsaClient.new(
      provider: "rfc3161_freetsa",
      url: "https://freetsa.org/tsr",
      timeout_seconds: 1,
      retry_count: 1,
      retry_backoff_seconds: 0
    )
    client.define_singleton_method(:post) do |_body|
      request_count += 1
      raise Timeout::Error, "timeout" if request_count == 1

      response
    end

    result = client.seal_digest(digest: Digest::SHA256.digest("audio"), hash_algorithm: "sha256")

    assert_equal RecordingIntegrityRecord::STATUS_SEALED, result.status
    assert_equal "freetsa.org", result.authority
    assert_equal RecordingIntegrityRecord::PROOF_FORMAT_RFC3161, result.proof_format
    assert_equal granted_rfc3161_response, Base64.strict_decode64(result.proof_blob)
    assert_equal Time.utc(2026, 3, 20, 10, 0, 0), result.timestamp
    assert_equal 2, request_count
  end

  test "tsa client returns failed on network error" do
    Net::HTTP.stubs(:start).raises(Errno::ECONNREFUSED)
    client = Nodl::Integrity::TsaClient.new(
      provider: "rfc3161_freetsa",
      url: "https://freetsa.org/tsr",
      timeout_seconds: 1,
      retry_count: 0,
      retry_backoff_seconds: 0
    )

    result = client.seal_digest(digest: Digest::SHA256.digest("audio"), hash_algorithm: "sha256")

    assert_equal RecordingIntegrityRecord::STATUS_FAILED, result.status
    assert result.error.present?
  ensure
    Net::HTTP.unstub(:start)
  end

  private

  def granted_rfc3161_response
    [ "300730030201003000" ].pack("H*")
  end

  def pending_config_result
    Nodl::Integrity::TimestampProofResult.new(
      status: RecordingIntegrityRecord::STATUS_PENDING_CONFIG,
      provider: "rfc3161_freetsa",
      authority: nil,
      proof_format: nil,
      proof_blob: nil,
      timestamp: nil,
      error: "TSA URL not configured."
    )
  end

  def seal_result(hash:, status:, proof: nil)
    Nodl::Integrity::SealResult.new(
      hash_sha256: hash,
      hash_algorithm: RecordingIntegrityRecord::HASH_ALGORITHM_SHA256,
      hashed_at: Time.current,
      tsa_status: status,
      tsa_provider: "rfc3161_freetsa",
      tsa_authority: "freetsa.org",
      tsa_proof_format: proof.present? ? RecordingIntegrityRecord::PROOF_FORMAT_RFC3161 : nil,
      tsa_proof_blob: proof,
      tsa_timestamp: proof.present? ? Time.current : nil,
      tsa_error: status == RecordingIntegrityRecord::STATUS_FAILED ? "offline" : nil
    )
  end
end
