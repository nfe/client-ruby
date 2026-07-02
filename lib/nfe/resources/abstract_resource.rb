# frozen_string_literal: true

require "json"

module Nfe
  module Resources
    # Base class for every SDK resource. Constructed with the owning
    # {Nfe::Client}, it provides the HTTP verb helpers (+get+/+post+/+put+/
    # +delete+) routed through the client's transport for the resource's declared
    # +api_family+, plus hydration and async-response helpers shared by every
    # resource.
    #
    # Subclasses declare their +api_family+ (and optionally override
    # +api_version+, which defaults to +"v1"+; the addresses resource returns
    # +""+ because its host already embeds +/v2+). Business methods are added by
    # the resource changes (add-invoice-resources, add-entity-resources, ...).
    #
    # All HTTP helpers accept an optional +request_options:+ ({Nfe::RequestOptions})
    # that is threaded through to {Nfe::Client#request} for per-call multi-tenant
    # overrides.
    class AbstractResource
      # @param client [Nfe::Client] the owning client.
      def initialize(client)
        @client = client
      end

      protected

      # @return [Nfe::Client] the owning client.
      attr_reader :client

      # The product family this resource belongs to (e.g. +:main+, +:cte+).
      # Subclasses MUST override.
      #
      # @return [Symbol]
      def api_family
        raise NotImplementedError, "#{self.class} must declare an api_family"
      end

      # The path version segment prefixed to every request path. Defaults to
      # +"v1"+; a resource whose host already embeds the version (addresses)
      # overrides this to +""+.
      #
      # @return [String]
      def api_version
        "v1"
      end

      # Issue a GET request for this resource's family.
      def get(path, query: {}, request_options: nil, headers: {})
        client.request(:get, family: api_family, path: full_path(path),
                             query: query, headers: headers,
                             request_options: request_options)
      end

      # Issue a POST request for this resource's family.
      def post(path, body: nil, query: {}, request_options: nil, headers: {},
               idempotency_key: nil)
        client.request(:post, family: api_family, path: full_path(path),
                              query: query, body: body, headers: headers,
                              idempotency_key: idempotency_key,
                              request_options: request_options)
      end

      # Issue a PUT request for this resource's family.
      def put(path, body: nil, query: {}, request_options: nil, headers: {})
        client.request(:put, family: api_family, path: full_path(path),
                             query: query, body: body, headers: headers,
                             request_options: request_options)
      end

      # Issue a DELETE request for this resource's family.
      def delete(path, query: {}, request_options: nil, headers: {})
        client.request(:delete, family: api_family, path: full_path(path),
                                query: query, headers: headers,
                                request_options: request_options)
      end

      # Prefix +path+ with +/#{api_version}+ unless the version is empty (in
      # which case +path+ is returned unchanged, avoiding a doubled slash).
      #
      # @param path [String]
      # @return [String]
      def full_path(path)
        version = api_version.to_s
        return path if version.empty?

        "/#{version}#{path}"
      end

      # Materialize a generated DTO by delegating to its +from_api+ factory
      # (camelCase -> snake_case, unknown-key drop, nested recursion). The
      # factory itself is produced by add-openapi-pipeline; this is only the
      # call site.
      #
      # @param klass [Class] a generated DTO class responding to +from_api+.
      # @param payload [Hash, nil]
      def hydrate(klass, payload)
        klass.from_api(payload)
      end

      # Perform a GET and return the response body as binary-safe bytes
      # (+ASCII-8BIT+), so binary documents (PDF/XML/ZIP) are not corrupted.
      #
      # @return [String] the body, encoded +ASCII-8BIT+.
      def download(path, query: {}, request_options: nil, headers: {})
        response = get(path, query: query, request_options: request_options,
                             headers: headers)
        (response.body || "").dup.force_encoding(Encoding::ASCII_8BIT)
      end

      # Unwrap +payload[wrapper_key]+, hydrate each item with +klass+, and build
      # an {Nfe::ListResponse} whose +page+ reflects the pagination shape:
      # page-style (+page_index+/+page_count+) or cursor-style
      # (+starting_after+/+ending_before+).
      #
      # @param klass [Class] generated DTO class for each item.
      # @param payload [Hash] the parsed response body.
      # @param wrapper_key [String, Symbol] key carrying the item array.
      # @return [Nfe::ListResponse]
      def hydrate_list(klass, payload, wrapper_key:)
        payload ||= {} #: Hash[untyped, untyped]
        raw_items = payload[wrapper_key.to_s] || payload[wrapper_key.to_sym] || []
        items = raw_items.map { |item| hydrate(klass, item) }
        Nfe::ListResponse.new(data: items, page: build_list_page(payload))
      end

      # Interpret an emission response. A 202 with a +Location+ header yields an
      # {Nfe::Pending} (its +invoice_id+ parsed from the final path segment); a
      # 202 without +Location+ is a protocol violation raising
      # {Nfe::InvoiceProcessingError}. A 201/200 hydrates +issued_klass+ from the
      # JSON body and yields an {Nfe::Issued}.
      #
      # @param response [Nfe::Http::Response]
      # @param issued_klass [Class] generated DTO for the materialized resource.
      # @return [Nfe::Pending, Nfe::Issued]
      def handle_async_response(response, issued_klass:)
        if response.status == 202
          location = response.location
          if location.nil? || location.empty?
            raise Nfe::InvoiceProcessingError.new(
              "Resposta 202 sem cabeçalho Location: não é possível identificar a nota em processamento.",
              status_code: response.status, response_headers: response.headers
            )
          end
          Nfe::Pending.new(invoice_id: extract_invoice_id(location), location: location)
        else
          Nfe::Issued.new(resource: hydrate(issued_klass, parse_json(response.body)))
        end
      end

      private

      # Detect the pagination shape of +payload+ and build the matching
      # {Nfe::ListPage}. Page-style takes precedence when paging fields exist.
      def build_list_page(payload)
        page_index = dig_key(payload, "pageIndex", :page_index)
        page_count = dig_key(payload, "pageCount", :page_count)
        total = payload["totalResults"] || dig_key(payload, "total", :total)

        return page_list_page(page_index, page_count, total) if page_index || page_count

        cursor_list_page(payload, total)
      end

      # Reads a value under either the camelCase (String) or snake_case (Symbol) key.
      def dig_key(payload, camel_key, snake_key)
        payload[camel_key] || payload[snake_key]
      end

      def page_list_page(page_index, page_count, total)
        Nfe::ListPage.new(page_index: page_index, page_count: page_count, total: total)
      end

      def cursor_list_page(payload, total)
        starting_after = dig_key(payload, "startingAfter", :starting_after)
        ending_before = dig_key(payload, "endingBefore", :ending_before)
        return Nfe::ListPage.new(total: total) unless starting_after || ending_before

        Nfe::ListPage.new(starting_after: starting_after, ending_before: ending_before, total: total)
      end

      # Extract the trailing id from a +Location+ path, e.g.
      # +/v1/companies/x/serviceinvoices/abc-123+ -> +"abc-123"+.
      def extract_invoice_id(location)
        match = location.match(%r{/([a-z0-9-]+)\z}i)
        match ? match[1] : nil
      end

      # Parse a JSON body, tolerating nil/empty/malformed bodies.
      def parse_json(body)
        return nil if body.nil? || body.empty?

        JSON.parse(body)
      rescue JSON::ParserError
        nil
      end

      # Unwrap an API envelope: return +payload[key]+ when present (String or
      # Symbol key), otherwise return +payload+ unchanged. Tolerant of a missing
      # envelope so callers can pass a wrapped or already-unwrapped Hash.
      #
      # @param payload [Hash, nil] the parsed response body.
      # @param key [String, Symbol] the envelope key (e.g. +"companies"+).
      # @return [Object] the unwrapped value, or +payload+.
      def unwrap(payload, key)
        return payload unless payload.is_a?(Hash)

        if payload.key?(key.to_s)
          payload[key.to_s]
        elsif payload.key?(key.to_sym)
          payload[key.to_sym]
        else
          payload
        end
      end

      # POST a +multipart/form-data+ body built from +parts+ using only Ruby
      # stdlib, introducing no new runtime dependency. Each part is either a
      # scalar field value (+String+) or a file part described by a Hash with
      # +:filename+, +:content+, and optional +:content_type+.
      #
      # The body is assembled as binary (+ASCII-8BIT+) so certificate bytes are
      # never corrupted, and the +Content-Type+ header carries the generated
      # boundary. The multipart body is intentionally never logged.
      #
      # @param path [String] request path (already family-relative).
      # @param parts [Hash{String,Symbol => String, Hash}] form fields/files.
      # @return [Nfe::Http::Response]
      def upload_multipart(path, parts)
        boundary = "----NfeBoundary#{parts.object_id}"
        body = build_multipart_body(parts, boundary)
        headers = { "Content-Type" => "multipart/form-data; boundary=#{boundary}" }
        post(path, body: body, headers: headers)
      end

      # Assemble the raw multipart/form-data body for +parts+ under +boundary+.
      def build_multipart_body(parts, boundary)
        buffer = String.new(encoding: Encoding::ASCII_8BIT)
        parts.each do |name, value|
          buffer << "--#{boundary}\r\n".b
          buffer << multipart_part(name.to_s, value)
        end
        buffer << "--#{boundary}--\r\n".b
        buffer
      end

      # Encode a single multipart part (scalar field or file).
      def multipart_part(name, value)
        part = String.new(encoding: Encoding::ASCII_8BIT)
        if value.is_a?(Hash)
          filename = value[:filename] || value["filename"] || "file"
          content_type = value[:content_type] || value["content_type"] || "application/octet-stream"
          content = value[:content] || value["content"] || ""
          part << %(Content-Disposition: form-data; name="#{name}"; filename="#{filename}"\r\n).b
          part << "Content-Type: #{content_type}\r\n\r\n".b
          part << content.dup.force_encoding(Encoding::ASCII_8BIT)
        else
          part << %(Content-Disposition: form-data; name="#{name}"\r\n\r\n).b
          part << value.to_s.dup.force_encoding(Encoding::ASCII_8BIT)
        end
        part << "\r\n".b
        part
      end
    end
  end
end
