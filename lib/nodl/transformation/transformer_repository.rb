require "pathname"
require_relative "../error"
require_relative "template"
require_relative "transformer"

module Nodl
  module Transformation
    class TransformerRepository
      TEMPLATE_EXTENSIONS = %w[.md .markdown .txt].freeze

      attr_reader :root_path

      def initialize(root_path: Rails.root.join("transformers"))
        @root_path = Pathname.new(root_path.to_s)
      end

      def fetch(handle)
        normalized_handle = normalize_handle(handle)
        transformer_path = root_path.join(normalized_handle)
        instructions_path = transformer_path.join("instructions.md")

        raise ValidationError, "Transformer not found: #{normalized_handle}" unless transformer_path.directory?
        raise ValidationError, "Transformer instructions missing: #{instructions_path}" unless instructions_path.file?

        Transformer.new(
          handle: normalized_handle,
          path: transformer_path,
          instructions: instructions_path.read,
          templates: load_templates(transformer_path)
        )
      end

      private

      def normalize_handle(handle)
        normalized = handle.to_s.strip.presence || "default"
        return normalized if normalized.match?(/\A[a-zA-Z0-9][a-zA-Z0-9_-]*\z/)

        raise ValidationError, "Transformer handle is invalid: #{normalized}"
      end

      def load_templates(transformer_path)
        templates_path = transformer_path.join("templates")
        return [] unless templates_path.directory?

        templates_path.children
          .select { |path| path.file? && TEMPLATE_EXTENSIONS.include?(path.extname.downcase) }
          .sort_by { |path| path.basename.to_s }
          .map do |path|
            Template.new(name: path.basename.to_s, path: path, content: path.read)
          end
      end
    end
  end
end
