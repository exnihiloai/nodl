module Nodl
  # Single definition point for defaults shared by the CLI (lib/nodl/cli.rb)
  # and the web pipeline (app/services). Both sides resolve models through the
  # helpers below so the env-var override names also live in exactly one place.
  module Defaults
    TRANSCRIBER_MODEL = "voxtral-mini-latest".freeze
    TRANSFORMER_MODEL = "gemini-3.1-flash-lite".freeze
    TRANSFORMER_HANDLE = "default".freeze

    def self.transcriber_model
      ENV.fetch("NODL_VOXTRAL_MODEL", TRANSCRIBER_MODEL)
    end

    def self.transformer_model
      ENV.fetch("NODL_GEMINI_TRANSFORMER_MODEL", TRANSFORMER_MODEL)
    end
  end
end
