module Nodl
  class Error < StandardError; end
  class ConfigurationError < Error; end
  class ValidationError < Error; end
  class GeminiError < Error; end
  class MistralError < Error; end
end
