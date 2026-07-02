# frozen_string_literal: true

require "psych"
require "digest"

module Nfe
  module Build
    # Raised when the generator cannot proceed (broken spec, invalid shape, etc.).
    class Error < StandardError; end

    # Loads and validates a single OpenAPI/Swagger spec file (YAML or JSON).
    #
    # Psych parses both YAML and JSON (JSON is valid YAML), so one loader path
    # covers ".yaml" and ".json". The raw file bytes are SHA-256 hashed for the
    # AUTO-GENERATED banner and sync guard.
    class SpecLoader
      def initialize(path)
        @path = path.to_s
        @raw = read_raw
        @document = parse
        validate!
      end

      attr_reader :path

      def basename
        File.basename(@path)
      end

      def hash
        "sha256:#{Digest::SHA256.hexdigest(@raw)}"
      end

      # The components.schemas map. Returns {} when absent (does NOT raise).
      def schemas
        components = @document["components"]
        return {} unless components.is_a?(Hash)

        schemas = components["schemas"]
        schemas.is_a?(Hash) ? schemas : {}
      end

      private

      def read_raw
        File.binread(@path)
      rescue SystemCallError => e
        raise Error, "Cannot read spec #{@path}: #{e.message}"
      end

      def parse
        Psych.safe_load(@raw, aliases: true)
      rescue Psych::Exception => e
        raise Error, "Cannot parse spec #{@path}: #{e.message}"
      end

      def validate!
        raise Error, "Spec root is not a Hash: #{@path}" unless @document.is_a?(Hash)
        return if @document.key?("openapi") || @document.key?("swagger")

        raise Error, "Spec #{@path} lacks an \"openapi\"/\"swagger\" version key"
      end
    end
  end
end
