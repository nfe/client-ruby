# frozen_string_literal: true

module Nfe
  # Base class for every error the SDK raises.
  #
  # All SDK errors derive from {Nfe::Error}, so consumer code can catch the
  # whole family with a single +rescue Nfe::Error+. Errors derived from an HTTP
  # response carry the response context (+status_code+, +request_id+,
  # +error_code+, +response_body+, +response_headers+) for diagnostics.
  #
  # {#to_h} returns a logging-safe Hash that deliberately omits the raw
  # response body and headers, which may carry secrets or PII.
  class Error < StandardError
    # @return [Integer, nil] HTTP status code, when derived from a response.
    attr_reader :status_code
    # @return [String, nil] server-supplied request/correlation id.
    attr_reader :request_id
    # @return [String, nil] machine-readable error code from the body.
    attr_reader :error_code
    # @return [String, nil] raw response body, for programmatic inspection.
    attr_reader :response_body
    # @return [Hash] response headers (lowercase keys).
    attr_reader :response_headers

    # @param message [String, nil] human-readable message.
    # @param status_code [Integer, nil]
    # @param request_id [String, nil]
    # @param error_code [String, nil]
    # @param response_body [String, nil]
    # @param response_headers [Hash]
    def initialize(message = nil, status_code: nil, request_id: nil,
                   error_code: nil, response_body: nil, response_headers: {})
      super(message)
      @status_code = status_code
      @request_id = request_id
      @error_code = error_code
      @response_body = response_body
      @response_headers = response_headers || {}
    end

    # Logging-safe representation. Never includes raw headers or body, which
    # could leak the API key, certificate password, or PII.
    #
    # @return [Hash]
    def to_h
      {
        type: self.class.name,
        message: message,
        status_code: status_code,
        request_id: request_id,
        error_code: error_code
      }
    end
  end

  # HTTP 401 — the API key is missing or invalid.
  class AuthenticationError < Error; end

  # HTTP 403 — the API key is valid but not authorized for the resource.
  class AuthorizationError < Error; end

  # HTTP 400/422 — the request was malformed or failed validation.
  class InvalidRequestError < Error; end

  # HTTP 404 — the requested resource does not exist.
  class NotFoundError < Error; end

  # HTTP 409 — the request conflicts with the current resource state.
  class ConflictError < Error; end

  # HTTP 429 — too many requests. Carries the optional +retry_after+ hint.
  class RateLimitError < Error
    # @return [Integer, nil] seconds to wait before retrying, when advertised.
    attr_reader :retry_after

    # @param retry_after [Integer, nil] from the +Retry-After+ header.
    def initialize(message = nil, retry_after: nil, **)
      super(message, **)
      @retry_after = retry_after
    end
  end

  # HTTP 5xx — the API failed to process the request.
  class ServerError < Error; end

  # A network-level failure (DNS, connection refused, TLS, reset). Raised
  # instead of returning a response, since no HTTP exchange completed.
  class ApiConnectionError < Error; end

  # A connection that timed out. A subclass of {ApiConnectionError} so a
  # +rescue Nfe::ApiConnectionError+ also catches timeouts.
  class TimeoutError < ApiConnectionError; end

  # Raised when a webhook signature fails verification.
  class SignatureVerificationError < Error; end

  # Raised when the SDK is misconfigured: a required API key is missing for a
  # family, or an invalid +environment+ was supplied. Raised client-side,
  # before any HTTP request is issued.
  class ConfigurationError < Error; end

  # Raised when an asynchronous (202) invoice response violates the expected
  # protocol — e.g., a 202 without a +Location+ header, or an +invoice_id+ that
  # cannot be extracted from it.
  class InvoiceProcessingError < Error; end
end
