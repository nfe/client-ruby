# frozen_string_literal: true

module Nfe
  module Http
    # Immutable value object describing a single HTTP response.
    #
    # A +Response+ carries the raw status code, normalized headers (lowercase
    # string keys), and a binary-safe body. HTTP errors (4xx/5xx) are returned as
    # ordinary responses — never raised — so the retry decorator and
    # {Nfe::ErrorFactory} can act on the status. Redirects and 202 are not
    # followed by the transport; the +Location+ header is preserved here.
    #
    #   response = Nfe::Http::Response.new(status: 200, headers: { "content-type" => "application/json" }, body: "{}")
    #   response.success?               # => true
    #   response.header("Content-Type") # => "application/json"
    class Response < Data.define(:status, :headers, :body)
      # @param status [Integer] HTTP status code.
      # @param headers [Hash{String=>String}] lowercase-keyed response headers.
      # @param body [String, nil] ASCII-8BIT response body, or nil.
      def initialize(status:, headers: {}, body: nil)
        super
      end

      # Case-insensitive header lookup.
      #
      # @param name [String] header name in any casing.
      # @return [String, nil] the header value, or nil when absent.
      def header(name)
        headers[name.downcase]
      end

      # @return [Boolean] true when the status is in the 2xx range.
      def success?
        (200..299).cover?(status)
      end

      # @return [String, nil] the +Location+ header, or nil.
      def location
        header("location")
      end
    end
  end
end
