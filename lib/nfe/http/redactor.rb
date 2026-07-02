# frozen_string_literal: true

module Nfe
  module Http
    # Replaces the values of sensitive headers with +"[REDACTED]"+ before they
    # reach a log line, so an API key, bearer token, or idempotency key never
    # appears verbatim in transport logs.
    #
    # A header is considered sensitive when its (case-insensitive) name is one of
    # +x-nfe-apikey+, +authorization+, +idempotency-key+, or matches
    # <tt>/secret|apikey|token/i</tt>. Benign headers are returned unchanged.
    module Redactor
      REDACTED = "[REDACTED]"

      # Exact (case-insensitive) header names that are always redacted.
      SENSITIVE_NAMES = %w[x-nfe-apikey authorization idempotency-key].freeze

      # Substring pattern matched against header names.
      SENSITIVE_PATTERN = /secret|apikey|token/i

      module_function

      # Returns a new Hash with the values of sensitive keys replaced by
      # +"[REDACTED]"+. The input hash is never mutated; benign keys keep their
      # original value and casing.
      def headers(hash)
        return hash unless hash.respond_to?(:each_pair)

        redacted = {} #: Hash[untyped, untyped]
        hash.each_pair { |key, value| redacted[key] = sensitive?(key) ? REDACTED : value }
        redacted
      end

      # Returns +true+ when a header named +key+ must have its value redacted.
      def sensitive?(key)
        name = key.to_s.downcase
        SENSITIVE_NAMES.include?(name) || SENSITIVE_PATTERN.match?(name)
      end
    end
  end
end
