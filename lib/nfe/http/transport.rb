# frozen_string_literal: true

module Nfe
  module Http
    # Transport contract: any object that turns a {Nfe::Http::Request} into a
    # {Nfe::Http::Response}.
    #
    # The SDK routes every HTTP call through an object responding to
    # +call(request)+. The default implementation is {Nfe::Http::NetHttp} (zero
    # external dependencies), but any duck-typed object satisfying this contract
    # may be substituted — a logging decorator, a retrying decorator, or an
    # in-memory fake for tests.
    #
    # == Contract
    #
    # An implementation of +call(request)+:
    #
    # * SHALL accept a {Nfe::Http::Request} and return a {Nfe::Http::Response}.
    # * SHALL return HTTP 4xx and 5xx outcomes as a +Response+ carrying that
    #   status — it SHALL NOT raise for them. The retry decorator and
    #   {Nfe::ErrorFactory} act on the status code.
    # * SHALL raise ONLY {Nfe::ApiConnectionError} (or its subclass
    #   {Nfe::TimeoutError}) on network failures — connection refused, DNS,
    #   TLS, read/connect timeouts.
    # * SHALL NOT follow HTTP 202 responses or redirects automatically; it
    #   SHALL preserve the raw status and the +Location+ header so the caller
    #   can implement the async Pending/Issued contract.
    # * SHALL normalize response header keys to lowercase strings and return a
    #   binary-safe (ASCII-8BIT) body.
    #
    # Mix this module in to inherit the +NotImplementedError+ default, or simply
    # define +call+ on any object (duck typing).
    module Transport
      # Perform the request.
      #
      # @param request [Nfe::Http::Request]
      # @return [Nfe::Http::Response]
      # @raise [NotImplementedError] unless overridden.
      def call(request)
        raise NotImplementedError, "#{self.class} must implement #call(request)"
      end
    end
  end
end
