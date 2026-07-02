# frozen_string_literal: true

require "json"

module Nfe
  # Translates HTTP responses and network exceptions into the typed
  # {Nfe::Error} hierarchy.
  #
  # The transport returns 4xx/5xx as {Nfe::Http::Response} objects (never
  # raising); the resource layer feeds those to {.from_response} to obtain the
  # right error class. Network failures the transport raised are normalized via
  # {.from_network_error}.
  #
  # The extracted message echoes server-controlled input, so it is capped to a
  # bounded length and stripped of control characters before reaching the
  # error — an attacker-controlled body must not flood logs or inject terminal
  # escape sequences.
  module ErrorFactory
    # Maximum length of a message extracted from a response body.
    MAX_MESSAGE_LENGTH = 500

    # Body keys searched (in order) for a human-readable message.
    MESSAGE_KEYS = %w[message error detail details].freeze

    # Body keys searched (in order) for a machine-readable error code.
    ERROR_CODE_KEYS = %w[code errorCode error_code].freeze

    # ASCII control characters (C0 range plus DEL) scrubbed from messages.
    CONTROL_CHARS = /[\x00-\x1f\x7f]/

    module_function

    # Build the appropriate {Nfe::Error} subclass for an HTTP response.
    #
    # @param response [Nfe::Http::Response] status:, #header(name), body:
    # @return [Nfe::Error]
    def from_response(response)
      status = response.status
      parsed = parse_body(response.body)

      message = extract_message(parsed) || "API request failed with HTTP #{status}"
      error_code = extract_error_code(parsed)
      request_id = response.header("x-request-id") || response.header("x-correlation-id")

      kwargs = {
        status_code: status,
        request_id: request_id,
        error_code: error_code,
        response_body: response.body,
        response_headers: response.headers
      }

      klass = error_class_for(status)
      if klass == RateLimitError
        RateLimitError.new(message, retry_after: extract_retry_after(response), **kwargs)
      else
        klass.new(message, **kwargs)
      end
    end

    # Normalize a network exception raised by the transport.
    #
    # @param exception [Exception]
    # @return [Nfe::ApiConnectionError]
    def from_network_error(exception)
      klass = timeout?(exception) ? TimeoutError : ApiConnectionError
      error = klass.new(exception.message)
      # Preserve the original exception as cause for debugging.
      begin
        raise error, error.message, cause: exception
      rescue klass => e
        e
      end
    end

    # @api private
    def error_class_for(status)
      case status
      when 401 then AuthenticationError
      when 403 then AuthorizationError
      when 404 then NotFoundError
      when 409 then ConflictError
      when 429 then RateLimitError
      when 400..499 then InvalidRequestError
      when 500..599 then ServerError
      else
        status >= 500 ? ServerError : InvalidRequestError
      end
    end

    # @api private
    def parse_body(body)
      return nil if body.nil? || body.empty?

      JSON.parse(body)
    rescue JSON::ParserError
      nil
    end

    # @api private
    def extract_message(parsed)
      return nil unless parsed.is_a?(Hash)

      raw = message_from_keys(parsed) || message_from_errors(parsed["errors"])
      sanitize_message(raw)
    end

    # @api private
    def message_from_keys(parsed)
      MESSAGE_KEYS.each do |key|
        value = parsed[key]
        return value if value.is_a?(String) && !value.empty?
      end
      nil
    end

    # @api private
    def message_from_errors(errors)
      case errors
      when String
        errors
      when Array
        first = errors[0]
        first.is_a?(Hash) ? first["message"] : first
      end
    end

    # @api private
    def sanitize_message(raw)
      return nil if raw.nil?

      # Scrub ASCII control characters (incl. ESC) so an attacker-controlled
      # body cannot inject terminal escape sequences, then cap the length.
      text = raw.to_s.gsub(CONTROL_CHARS, " ").strip
      return nil if text.empty?

      text.length > MAX_MESSAGE_LENGTH ? "#{text[0, MAX_MESSAGE_LENGTH]}..." : text
    end

    # @api private
    def extract_error_code(parsed)
      return nil unless parsed.is_a?(Hash)

      ERROR_CODE_KEYS.each do |key|
        value = parsed[key]
        return value.to_s if value.is_a?(String) || value.is_a?(Integer)
      end
      nil
    end

    # @api private
    def extract_retry_after(response)
      value = response.header("retry-after")
      return nil if value.nil?

      Integer(value, 10)
    rescue ArgumentError, TypeError
      nil
    end

    # @api private
    def timeout?(exception)
      timeout_class_names = %w[Net::OpenTimeout Net::ReadTimeout Timeout::Error]
      ancestor_names = exception.class.ancestors.map(&:to_s)
      timeout_class_names.intersect?(ancestor_names)
    end
  end
end
