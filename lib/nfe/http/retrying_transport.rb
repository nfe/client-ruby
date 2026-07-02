# frozen_string_literal: true

module Nfe
  module Http
    # Transport decorator that retries transient failures on idempotent
    # requests. Wraps any +inner+ transport (any object responding to
    # +call(request)+) and applies a {RetryPolicy}.
    #
    # Retries happen on HTTP 429, HTTP 500-599, and network errors
    # ({Nfe::ApiConnectionError}, including {Nfe::TimeoutError}) -- but ONLY
    # when {Request#idempotent?} is true. A +POST+ without an +idempotency_key+
    # is never retried, so an invoice is never re-issued automatically.
    #
    # An integer +Retry-After+ header (seconds) overrides the computed backoff,
    # clamped to the policy's +max_delay+.
    #
    # When a duck-typed +logger+ (responding to +info+/+warn+/+error+) is
    # supplied, the decorator logs request start (+info+), retries (+warn+), and
    # final failures (+error+). Sensitive headers are redacted via
    # {Redactor.headers} and request/response BODIES are never logged. Every log
    # call is wrapped in +rescue StandardError+ so logging can never break the
    # request.
    class RetryingTransport
      # @param inner    [#call] the wrapped transport
      # @param policy   [RetryPolicy] backoff policy
      # @param sleep_fn [#call] injectable sleep, called with seconds
      # @param logger   [#info, #warn, #error, nil] optional duck-typed logger
      def initialize(inner:, policy: RetryPolicy.default, sleep_fn: ->(seconds) { Kernel.sleep(seconds) }, logger: nil)
        @inner = inner
        @policy = policy
        @sleep_fn = sleep_fn
        @logger = logger
      end

      # Execute +request+ through the inner transport, retrying transient
      # failures on idempotent requests. Returns an {Nfe::Http::Response}; on a
      # non-retryable network failure (or after exhausting retries) re-raises
      # the last {Nfe::ApiConnectionError}.
      def call(request)
        log_start(request)
        attempt = 0

        loop do
          begin
            response = @inner.call(request)
          rescue Nfe::ApiConnectionError => e
            attempt += 1
            unless retry_again?(attempt, request)
              log_final_error(request, error: e)
              raise
            end
            delay = @policy.delay_for(attempt)
            log_retry(request, attempt: attempt, delay: delay, error: e)
            @sleep_fn.call(delay)
            next
          end

          unless retryable_status?(response.status) && retry_again?(attempt + 1, request)
            log_final_error(request, response: response) unless response.success?
            return response
          end

          attempt += 1
          delay = delay_for_response(attempt, response)
          log_retry(request, attempt: attempt, delay: delay, status: response.status)
          @sleep_fn.call(delay)
        end
      end

      # True for statuses that warrant a retry: 429 and 5xx.
      def retryable_status?(status)
        status == 429 || (500..599).cover?(status)
      end

      private

      # An +attempt+ (1-based retry index) is permitted when it does not exceed
      # the configured maximum and the request is idempotent.
      def retry_again?(attempt, request)
        attempt <= @policy.max_retries && request.idempotent?
      end

      # Honor an integer +Retry-After+ (seconds), clamped to +max_delay+;
      # otherwise fall back to the policy backoff.
      def delay_for_response(attempt, response)
        retry_after = parse_retry_after(response)
        return [retry_after.to_f, @policy.max_delay].min if retry_after

        @policy.delay_for(attempt)
      end

      def parse_retry_after(response)
        raw = response.header("retry-after")
        return nil if raw.nil?
        return nil unless raw.to_s.match?(/\A\d+\z/)

        raw.to_i
      end

      def log_start(request)
        return unless @logger

        safe_log do
          @logger.info("nfe-io request: #{request.method.to_s.upcase} #{request.url} " \
                       "headers=#{Redactor.headers(request.headers).inspect}")
        end
      end

      def log_retry(request, attempt:, delay:, status: nil, error: nil)
        return unless @logger

        reason = error ? "error=#{error.class}" : "status=#{status}"
        safe_log do
          @logger.warn("nfe-io retry ##{attempt} in #{delay}s: " \
                       "#{request.method.to_s.upcase} #{request.url} #{reason}")
        end
      end

      def log_final_error(request, response: nil, error: nil)
        return unless @logger

        detail = if error
                   "error=#{error.class}"
                 elsif response
                   "status=#{response.status} body=#{truncate(response.body)}"
                 else
                   "unknown failure"
                 end
        safe_log do
          @logger.error("nfe-io request failed: #{request.method.to_s.upcase} #{request.url} #{detail}")
        end
      end

      def truncate(body, limit = 256)
        return "" if body.nil?

        string = body.to_s
        string.bytesize > limit ? "#{string.byteslice(0, limit)}...(truncated)" : string
      end

      # Logging must never break the request.
      def safe_log
        yield
      rescue StandardError
        nil
      end
    end
  end
end
