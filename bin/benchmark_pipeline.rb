#!/usr/bin/env ruby

require_relative "../config/environment"
require "benchmark"
require "pathname"

# Load Nodl components explicitly
require "nodl/audio/waveform_extractor"
require "nodl/audio_input"
require "nodl/transcription/voxtral_transcriber"
require "nodl/transformation/gemini_document_transformer"
require "nodl/transformation/transformer_repository"

def print_usage
  puts "Usage: bin/benchmark_pipeline.rb <path_to_audio_file> [--transformer HANDLE]"
  puts "Example: bin/benchmark_pipeline.rb private/test-data/precht-2min.mp3"
end

if ARGV.empty? || ARGV.include?("-h") || ARGV.include?("--help")
  print_usage
  exit 1
end

audio_path = Pathname.new(ARGV[0])
unless audio_path.exist?
  # Try checking relative to Rails root
  audio_path = Rails.root.join(audio_path)
  unless audio_path.exist?
    puts "Error: File not found at #{ARGV[0]}"
    exit 1
  end
end

transformer_handle = "default"
if ARGV.include?("--transformer")
  idx = ARGV.index("--transformer")
  transformer_handle = ARGV[idx + 1] if idx && ARGV[idx + 1]
end

puts "=== Benchmarking Nodl Pipeline ==="
puts "File: #{audio_path}"
puts "Size: #{(audio_path.size.to_f / 1.megabyte).round(2)} MB"
puts "Transformer: #{transformer_handle}"
puts "----------------------------------"

# Initialize components
transcriber_model = ENV.fetch("NODL_VOXTRAL_MODEL", "voxtral-mini-latest")
transformer_model = ENV.fetch("NODL_GEMINI_TRANSFORMER_MODEL", "gemini-3.1-flash-lite")

waveform_extractor = Nodl::Audio::WaveformExtractor.new
transcriber = Nodl::Transcription::VoxtralTranscriber.new
document_transformer = Nodl::Transformation::GeminiDocumentTransformer.new
transformer_repository = Nodl::Transformation::TransformerRepository.new
transformer = transformer_repository.fetch(transformer_handle)

source_audio = Nodl::AudioInput.new(audio_path)

waveform = nil
duration = 0.0
waveform_time = Benchmark.realtime do
  waveform = waveform_extractor.extract(audio_path)
  duration = waveform.duration
rescue StandardError => e
  puts "Waveform extraction failed: #{e.message}"
end

puts "Audio Duration: #{duration.round(2)}s (#{(duration / 60.0).round(2)} min)"
puts "Waveform extraction: #{waveform_time.round(2)}s"

transcript = nil
transcribe_time = Benchmark.realtime do
  print "Transcribing with #{transcriber_model}..."
  $stdout.flush
  transcript = transcriber.transcribe(audio: source_audio, model: transcriber_model)
  puts " Done."
end

puts "Transcription time: #{transcribe_time.round(2)}s"
puts "Transcript language: #{transcript.language}"
puts "Transcript length: #{transcript.text.to_s.length} characters"

document = nil
document_time = Benchmark.realtime do
  print "Creating document with #{transformer_model}..."
  $stdout.flush
  document = document_transformer.transform(
    transcript: transcript.text,
    transformer: transformer,
    model: transformer_model
  )
  puts " Done."
end

puts "Document creation time: #{document_time.round(2)}s"
puts "Document length: #{document.to_s.length} characters"

total_time = waveform_time + transcribe_time + document_time
puts "----------------------------------"
puts "SUMMARY:"
puts "Transcription stage: #{transcribe_time.round(2)}s"
puts "Document stage     : #{document_time.round(2)}s"
puts "Total time         : #{total_time.round(2)}s"
if duration > 0
  puts "Speed ratio        : #{(duration / total_time).round(2)}x realtime"
end
puts "=================================="
