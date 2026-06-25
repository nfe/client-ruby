# frozen_string_literal: true

require "net/http"
require "uri"
require "openssl"
require "zlib"
require "stringio"

module Nfe
  module Http
    # Default, zero-dependency HTTP transport built on the Ruby standard library
    # (+net/http+, +uri+, +openssl+, +zlib+, +stringio+). It satisfies the
    # {Nfe::Http::Transport} contract: it returns 4xx/5xx as ordinary
    # {Nfe::Http::Response} objects, raises only {Nfe::ApiConnectionError} (or its
    # subclass {Nfe::TimeoutError}) on network failure, and never follows a
    # redirect or 202.
    #
    # Connections are pooled per origin (<tt>"host:port"</tt>) and kept alive for
    # TCP/TLS reuse. The pool is guarded by a +Mutex+ and follows a
    # checkout/check-in model: a connection is removed from the idle list while a
    # request is in flight and only returned afterwards. A single instance is
    # therefore safe to share across threads (Rails/Sidekiq/Puma): two in-flight
    # requests never share the same socket, and a connection broken by a network
    # error is closed instead of being returned to the pool.
    #
    # TLS is always enforced for +https+ origins with
    # +OpenSSL::SSL::VERIFY_PEER+; verification is never disabled. An optional
    # +ca_file+ provides an escape hatch for a legacy CA store.
    class NetHttp
      # Seconds an idle pooled connection is kept open for reuse.
      KEEP_ALIVE_TIMEOUT = 30

      def initialize(default_open_timeout: 10, default_read_timeout: 60, ca_file: nil)
        @default_open_timeout = default_open_timeout
        @default_read_timeout = default_read_timeout
        @ca_file = ca_file
        @pool = {}
        @mutex = Mutex.new
      end

      # Executes +request+ and returns an {Nfe::Http::Response}. Raises
      # {Nfe::TimeoutError} on open/read timeout and {Nfe::ApiConnectionError} on
      # any other network-level failure.
      def call(request)
        uri = URI.parse(request.url)
        key = origin_key(uri)
        http = nil
        begin
          # checkout starts the connection (http.start), which can itself raise a
          # network error (e.g. ECONNREFUSED) — keep it inside the rescue.
          http = checkout(key, uri, request)
          net_response = http.request(build_net_request(uri, request))
          checkin(key, http)
          build_response(net_response)
        rescue Timeout::Error => e
          # Net::OpenTimeout and Net::ReadTimeout both descend from Timeout::Error.
          discard(http) if http
          raise Nfe::TimeoutError, e.message
        rescue SocketError, SystemCallError, OpenSSL::SSL::SSLError,
               Net::HTTPBadResponse, IOError => e
          # IOError covers EOFError; SystemCallError covers all Errno::* errors.
          discard(http) if http
          raise Nfe::ApiConnectionError, e.message
        end
      end

      private

      # Removes an idle connection for +key+ from the pool (or builds a fresh,
      # started one) and hands it to the caller. While the connection is in flight
      # it is owned exclusively by this call and absent from the pool, so no other
      # thread can use the same socket concurrently. Timeouts are applied per call.
      def checkout(key, uri, request)
        http = @mutex.synchronize { (@pool[key] ||= []).pop } || build_connection(uri)
        apply_timeouts(http, request)
        http.start unless http.started?
        http
      end

      # Returns a healthy connection to the idle list for reuse.
      def checkin(key, http)
        @mutex.synchronize { (@pool[key] ||= []) << http }
      end

      # Closes a connection broken by a network error so it is never reused.
      def discard(http)
        http.finish if http.started?
      rescue IOError, SystemCallError
        # Socket already torn down; nothing left to close.
      end

      def build_connection(uri)
        http = Net::HTTP.new(uri.host.to_s, uri.port)
        http.keep_alive_timeout = KEEP_ALIVE_TIMEOUT
        configure_tls(http, uri)
        http
      end

      def configure_tls(http, uri)
        return unless uri.scheme == "https"

        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER
        http.ca_file = @ca_file if @ca_file
      end

      def apply_timeouts(http, request)
        http.open_timeout = request.open_timeout || @default_open_timeout
        http.read_timeout = request.read_timeout || @default_read_timeout
      end

      def origin_key(uri)
        "#{uri.host}:#{uri.port}"
      end

      # Builds the appropriate Net::HTTP request object, copying headers and body
      # from the {Nfe::Http::Request} and defaulting +Accept-Encoding: gzip+ when
      # the caller has not set it.
      def build_net_request(uri, request)
        net_request = request_class(request.method).new(uri)
        request.headers.each { |name, value| net_request[name.to_s] = value }
        net_request["Accept-Encoding"] = "gzip" unless accept_encoding_set?(request.headers)
        net_request.body = request.body unless request.body.nil?
        net_request
      end

      def accept_encoding_set?(headers)
        headers.any? { |name, _| name.to_s.downcase == "accept-encoding" }
      end

      def request_class(method)
        case method.to_s.upcase
        when "GET"    then Net::HTTP::Get
        when "POST"   then Net::HTTP::Post
        when "PUT"    then Net::HTTP::Put
        when "DELETE" then Net::HTTP::Delete
        when "HEAD"   then Net::HTTP::Head
        else raise Nfe::ApiConnectionError, "Unsupported HTTP method: #{method}"
        end
      end

      # Maps a Net::HTTPResponse into an {Nfe::Http::Response}: integer status,
      # lowercase headers (multi-value joined with ", "), and a binary body. A
      # gzip body is inflated transparently. Redirects and 202 are not followed.
      def build_response(net_response)
        status = net_response.code.to_i
        headers = normalize_headers(net_response)
        body = (net_response.body || "").dup.force_encoding(Encoding::ASCII_8BIT)
        body, headers = decompress(body, headers)
        Nfe::Http::Response.new(status: status, headers: headers, body: body)
      end

      def normalize_headers(net_response)
        headers = {} #: Hash[String, String]
        net_response.each_capitalized do |name, value|
          key = name.downcase
          headers[key] = headers.key?(key) ? "#{headers[key]}, #{value}" : value
        end
        headers
      end

      # Inflates a gzip body and drops the now-stale +content-encoding+ and
      # +content-length+ headers. On a malformed stream the raw body is kept and a
      # warning is emitted, never raising.
      def decompress(body, headers)
        return [body, headers] unless headers["content-encoding"].to_s.downcase.include?("gzip")

        inflated = Zlib::GzipReader.new(StringIO.new(body)).read.to_s.force_encoding(Encoding::ASCII_8BIT)
        cleaned = headers.dup
        cleaned.delete("content-encoding")
        cleaned.delete("content-length")
        [inflated, cleaned]
      rescue Zlib::Error => e
        warn("Nfe::Http::NetHttp: failed to inflate gzip response body: #{e.message}")
        [body, headers]
      end
    end
  end
end
