# frozen_string_literal: true

require "uri"

module Nfe
  module Http
    # Immutable value object describing a single outbound HTTP request.
    #
    # A +Request+ is transport-agnostic: it carries everything a transport needs
    # to perform one HTTP call, including its own +base_url+ (enabling multi-host
    # routing) and optional per-call timeout overrides. Headers, query, and body
    # are supplied verbatim; the transport is responsible for wire encoding.
    #
    #   request = Nfe::Http::Request.new(
    #     method: "GET",
    #     base_url: "https://api.nfse.io",
    #     path: "/v2/companies/abc/productinvoices",
    #     query: { environment: "Production", limit: 50 }
    #   )
    #   request.url # => ".../productinvoices?environment=Production&limit=50"
    #
    # The +method+ member intentionally exposes the HTTP verb as +request.method+;
    # it shadows +Object#method+, which the value object never relies on.
    class Request < Data.define(
      :method, :base_url, :path, :headers, :query, :body,
      :open_timeout, :read_timeout, :idempotency_key
    )
      # @param method [String] HTTP method (e.g. "GET", "POST").
      # @param base_url [String] origin + optional prefix (e.g. "https://api.nfse.io").
      # @param path [String] request path (e.g. "/v2/companies").
      # @param headers [Hash] request headers, sent verbatim by the transport.
      # @param query [Hash] query parameters; array values become repeated keys.
      # @param body [String, nil] raw request body, or nil.
      # @param open_timeout [Numeric, nil] per-call connect timeout override.
      # @param read_timeout [Numeric, nil] per-call read timeout override.
      # @param idempotency_key [String, nil] optional key; makes a POST retry-eligible.
      def initialize(method:, base_url:, path:, headers: {}, query: {}, body: nil,
                     open_timeout: nil, read_timeout: nil, idempotency_key: nil)
        super
      end

      # Composes the final URL from +base_url+, +path+, and the URL-encoded +query+.
      #
      # A trailing slash on +base_url+ is stripped. When +query+ is non-empty the
      # encoded form is appended with "?" (or "&" when +path+ already contains a
      # "?"). Array query values are emitted as repeated keys.
      #
      # @return [String]
      def url
        base = base_url.chomp("/") + path
        return base if query.nil? || query.empty?

        separator = base.include?("?") ? "&" : "?"
        "#{base}#{separator}#{URI.encode_www_form(query)}"
      end

      # Whether this request is safe to retry.
      #
      # @return [Boolean] true for GET/HEAD/PUT/DELETE (case-insensitive) or any
      #   request carrying a non-nil +idempotency_key+.
      def idempotent?
        return true unless idempotency_key.nil?

        %w[GET HEAD PUT DELETE].include?(method.to_s.upcase)
      end
    end
  end
end
