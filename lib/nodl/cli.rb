require "optparse"
require "pathname"
require_relative "error"
require_relative "pipeline"

module Nodl
  class Cli
    HelpRequested = Class.new(StandardError)

    DEFAULT_TRANSFORMER = "default"
    DEFAULT_MODEL = "gemini-3.1-flash-lite"
    COMMANDS = %w[run transcribe].freeze

    def initialize(argv, output: $stdout, error_output: $stderr)
      @argv = argv.dup
      @output = output
      @error_output = error_output
    end

    def call
      options = parse_options
      result = Pipeline.new(working_directory: WorkingDirectory.new(root_path: options.fetch(:work_dir))).run(
        audio_path: options.fetch(:audio_path),
        transformer_handle: options.fetch(:transformer),
        transcriber_model: options.fetch(:transcriber_model),
        transformer_model: options.fetch(:transformer_model)
      )
      print_result(result)
      0
    rescue HelpRequested
      0
    rescue Error, OptionParser::ParseError, KeyError => error
      error_output.puts("Error: #{error.message}")
      error_output.puts
      error_output.puts(parser_banner)
      1
    end

    private

    attr_reader :argv, :output, :error_output

    def parsed_options
      @parsed_options ||= {}
    end

    def option_parser
      @option_parser ||= OptionParser.new(parser_banner) do |opts|
        opts.on("--transformer HANDLE", "Transformer folder handle. Default: default") do |value|
          parsed_options[:transformer] = value
        end
        opts.on("--work-dir PATH", "Working sessions directory. Default: work/sessions") do |value|
          parsed_options[:work_dir] = Pathname.new(value)
        end
        opts.on("--transcriber-model MODEL", "Gemini transcription model.") do |value|
          parsed_options[:transcriber_model] = value
        end
        opts.on("--transformer-model MODEL", "Gemini document transformation model.") do |value|
          parsed_options[:transformer_model] = value
        end
        opts.on("-h", "--help", "Show help.") do
          output.puts(parser_banner)
          raise HelpRequested
        end
      end
    end

    def parse_options
      command = argv.shift
      raise ValidationError, "Command is required." unless COMMANDS.include?(command)

      options = {
        transformer: DEFAULT_TRANSFORMER,
        work_dir: Rails.root.join("work", "sessions"),
        transcriber_model: ENV.fetch("NODL_GEMINI_TRANSCRIBER_MODEL", DEFAULT_MODEL),
        transformer_model: ENV.fetch("NODL_GEMINI_TRANSFORMER_MODEL", DEFAULT_MODEL)
      }

      option_parser.parse!(argv)
      audio_path = argv.shift
      raise ValidationError, "Audio file path is required." if audio_path.blank?
      raise ValidationError, "Unexpected arguments: #{argv.join(" ")}" if argv.any?

      options.merge(parsed_options).merge(audio_path: audio_path)
    end

    def print_result(result)
      output.puts("Session: #{result.session_path}")
      output.puts("Audio: #{result.audio_path}")
      output.puts("Transcript: #{result.transcript_path}")
      output.puts("Document: #{result.document_path}")
      output.puts("Metadata: #{result.metadata_path}")
    end

    def parser_banner
      <<~BANNER
        Usage:
          bin/nodl run AUDIO_PATH [options]
          bin/nodl transcribe AUDIO_PATH [options]

        Options:
      BANNER
    end
  end
end
