# frozen_string_literal: true

require "json"
require "nfe/resources/abstract_resource"
require "nfe/resources/dto/product_invoice"
require "nfe/resources/dto/nfe_file_resource"
require "nfe/resources/responses/product_invoice_pending"
require "nfe/resources/responses/product_invoice_issued"

module Nfe
  module Resources
    # Product invoices (NF-e) resource for the +:cte+ host family
    # (+https://api.nfse.io/v2/...+). Full NF-e lifecycle: issue, list, retrieve,
    # cancel, correction letters (CC-e), disablement (inutilização) and file
    # downloads.
    #
    # Emission is asynchronous (HTTP 202, queued; completion via webhook):
    # {#create}/{#create_with_state_tax} return either a
    # {Nfe::Resources::ProductInvoicePending} or a
    # {Nfe::Resources::ProductInvoiceIssued}. There is no
    # +create_and_wait+/+create_batch+ in v1.0 — poll manually with
    # {#retrieve} + {Nfe::FlowStatus.terminal?}.
    #
    # NOTE: unlike the other invoice resources, the download methods return a
    # {Nfe::NfeFileResource} (a URI to the file), NOT raw bytes.
    class ProductInvoices < AbstractResource
      protected

      def api_family
        :cte
      end

      # The +:cte+ host serves the v2 API; paths embed +/v2+ explicitly, so no
      # version segment is auto-prefixed.
      def api_version
        ""
      end

      public

      # Issue a product invoice (NF-e). Returns a discriminated result: a
      # {ProductInvoicePending} on HTTP 202 or a {ProductInvoiceIssued} on 201.
      #
      # @param company_id [String]
      # @param data [Hash] invoice payload (camelCase keys per the API).
      # @param idempotency_key [String, nil] sent as the +Idempotency-Key+ header.
      # @param request_options [Nfe::RequestOptions, nil] per-call overrides.
      # @return [ProductInvoicePending, ProductInvoiceIssued]
      def create(company_id:, data:, idempotency_key: nil, request_options: nil)
        cid = Nfe::IdValidator.company_id(company_id)
        response = post(base_path(cid), body: json_body(data), headers: json_headers,
                                        idempotency_key: idempotency_key,
                                        request_options: request_options)
        discriminate(response)
      end

      # Issue a product invoice scoped to a state tax registration.
      #
      # @param company_id [String]
      # @param state_tax_id [String]
      # @param data [Hash]
      # @param idempotency_key [String, nil]
      # @param request_options [Nfe::RequestOptions, nil]
      # @return [ProductInvoicePending, ProductInvoiceIssued]
      def create_with_state_tax(company_id:, state_tax_id:, data:, idempotency_key: nil, request_options: nil)
        cid = Nfe::IdValidator.company_id(company_id)
        sid = Nfe::IdValidator.state_tax_id(state_tax_id)
        response = post("/v2/companies/#{cid}/statetaxes/#{sid}/productinvoices",
                        body: json_body(data), headers: json_headers,
                        idempotency_key: idempotency_key, request_options: request_options)
        discriminate(response)
      end

      # List product invoices (cursor-style). +environment+ is REQUIRED.
      #
      # @param company_id [String]
      # @param environment [String] +"Production"+ or +"Test"+ (required).
      # @param options [Hash] +starting_after+, +ending_before+, +limit+, +q+.
      # @return [Nfe::ListResponse]
      # @raise [Nfe::InvalidRequestError] when +environment+ is missing.
      def list(company_id:, environment:, **options)
        cid = Nfe::IdValidator.company_id(company_id)
        require_environment(environment)
        query = cursor_query(options).merge(environment: environment)
        response = get(base_path(cid), query: query)
        hydrate_list(Nfe::ProductInvoice, parse_json(response.body), wrapper_key: "productInvoices")
      end

      # Retrieve a product invoice by id.
      #
      # @param company_id [String]
      # @param invoice_id [String]
      # @return [Nfe::ProductInvoice]
      def retrieve(company_id:, invoice_id:)
        cid = Nfe::IdValidator.company_id(company_id)
        iid = Nfe::IdValidator.invoice_id(invoice_id)
        response = get("#{base_path(cid)}/#{iid}")
        hydrate(Nfe::ProductInvoice, parse_json(response.body))
      end

      # Cancel a product invoice (async); +reason+ forwarded as a query param.
      #
      # @param company_id [String]
      # @param invoice_id [String]
      # @param reason [String, nil]
      # @return [Hash] the cancellation resource payload.
      def cancel(company_id:, invoice_id:, reason: nil)
        cid = Nfe::IdValidator.company_id(company_id)
        iid = Nfe::IdValidator.invoice_id(invoice_id)
        response = delete("#{base_path(cid)}/#{iid}", query: { reason: reason }.compact)
        parse_json(response.body) || {}
      end

      # List items of an invoice (cursor-style).
      #
      # @return [Nfe::ListResponse]
      def list_items(company_id:, invoice_id:, limit: nil, starting_after: nil)
        sub_list(company_id: company_id, invoice_id: invoice_id, segment: "items",
                 limit: limit, starting_after: starting_after, wrapper_key: "items")
      end

      # List fiscal events of an invoice (cursor-style).
      #
      # @return [Nfe::ListResponse]
      def list_events(company_id:, invoice_id:, limit: nil, starting_after: nil)
        sub_list(company_id: company_id, invoice_id: invoice_id, segment: "events",
                 limit: limit, starting_after: starting_after, wrapper_key: "events")
      end

      # DANFE PDF file resource (URI, not bytes). +force+ regenerates the PDF.
      #
      # @return [Nfe::NfeFileResource]
      def download_pdf(company_id:, invoice_id:, force: nil)
        file_resource(company_id: company_id, invoice_id: invoice_id,
                      segment: "pdf", query: { force: force }.compact)
      end

      # Authorized NF-e XML file resource (URI, not bytes).
      #
      # @return [Nfe::NfeFileResource]
      def download_xml(company_id:, invoice_id:)
        file_resource(company_id: company_id, invoice_id: invoice_id, segment: "xml")
      end

      # Rejection XML file resource (URI, not bytes).
      #
      # @return [Nfe::NfeFileResource]
      def download_rejection_xml(company_id:, invoice_id:)
        file_resource(company_id: company_id, invoice_id: invoice_id, segment: "xml-rejection")
      end

      # Contingency authorization (EPEC) XML file resource (URI, not bytes).
      #
      # @return [Nfe::NfeFileResource]
      def download_epec_xml(company_id:, invoice_id:)
        file_resource(company_id: company_id, invoice_id: invoice_id, segment: "xml-epec")
      end

      # Send a correction letter (CC-e). +reason+ must be 15..1000 chars; the
      # length is validated client-side before any HTTP request.
      #
      # @param company_id [String]
      # @param invoice_id [String]
      # @param reason [String]
      # @return [Hash] the cancellation/CC-e resource payload.
      # @raise [Nfe::InvalidRequestError] when +reason+ length is out of range.
      def send_correction_letter(company_id:, invoice_id:, reason:)
        cid = Nfe::IdValidator.company_id(company_id)
        iid = Nfe::IdValidator.invoice_id(invoice_id)
        validate_correction_reason(reason)
        response = put("#{base_path(cid)}/#{iid}/correctionletter",
                       body: json_body({ reason: reason }), headers: json_headers)
        parse_json(response.body) || {}
      end

      # CC-e DANFE PDF file resource (URI, not bytes).
      #
      # @return [Nfe::NfeFileResource]
      def download_correction_letter_pdf(company_id:, invoice_id:)
        file_resource(company_id: company_id, invoice_id: invoice_id, segment: "correctionletter/pdf")
      end

      # CC-e XML file resource (URI, not bytes).
      #
      # @return [Nfe::NfeFileResource]
      def download_correction_letter_xml(company_id:, invoice_id:)
        file_resource(company_id: company_id, invoice_id: invoice_id, segment: "correctionletter/xml")
      end

      # Disable (inutilizar) a single invoice (async). +reason+ optional.
      #
      # @return [Hash] the cancellation resource payload.
      def disable(company_id:, invoice_id:, reason: nil)
        cid = Nfe::IdValidator.company_id(company_id)
        iid = Nfe::IdValidator.invoice_id(invoice_id)
        response = post("#{base_path(cid)}/#{iid}/disablement", query: { reason: reason }.compact)
        parse_json(response.body) || {}
      end

      # Disable a range of invoice numbers (single number = same begin/last).
      #
      # @param company_id [String]
      # @param data [Hash] +{ environment, serie, state, begin_number, last_number, reason? }+.
      # @return [Hash] the disablement resource payload.
      def disable_range(company_id:, data:)
        cid = Nfe::IdValidator.company_id(company_id)
        response = post("#{base_path(cid)}/disablement", body: json_body(data), headers: json_headers)
        parse_json(response.body) || {}
      end

      private

      def base_path(company_id)
        "/v2/companies/#{company_id}/productinvoices"
      end

      def json_headers
        { "Content-Type" => "application/json" }
      end

      def json_body(data)
        JSON.generate(data)
      end

      def require_environment(environment)
        return unless environment.nil? || environment.to_s.strip.empty?

        raise Nfe::InvalidRequestError, "environment é obrigatório (Production ou Test)"
      end

      def cursor_query(options)
        {
          startingAfter: options[:starting_after], endingBefore: options[:ending_before],
          limit: options[:limit], q: options[:q]
        }.compact
      end

      def validate_correction_reason(reason)
        length = reason.to_s.length
        return if length.between?(15, 1000)

        raise Nfe::InvalidRequestError,
              "motivo da carta de correção deve conter entre 15 e 1000 caracteres"
      end

      def sub_list(company_id:, invoice_id:, segment:, limit:, starting_after:, wrapper_key:)
        cid = Nfe::IdValidator.company_id(company_id)
        iid = Nfe::IdValidator.invoice_id(invoice_id)
        query = { limit: limit, startingAfter: starting_after }.compact
        response = get("#{base_path(cid)}/#{iid}/#{segment}", query: query)
        hydrate_list(Nfe::ProductInvoice, parse_json(response.body), wrapper_key: wrapper_key)
      end

      def file_resource(company_id:, invoice_id:, segment:, query: {})
        cid = Nfe::IdValidator.company_id(company_id)
        iid = Nfe::IdValidator.invoice_id(invoice_id)
        response = get("#{base_path(cid)}/#{iid}/#{segment}", query: query)
        hydrate(Nfe::NfeFileResource, parse_json(response.body))
      end

      # Interpret the emission response into the discriminated value object.
      def discriminate(response)
        return build_pending(response) if response.status == 202

        ProductInvoiceIssued.new(resource: hydrate(Nfe::ProductInvoice, parse_json(response.body)))
      end

      # Build a {ProductInvoicePending} from a 202 response, or raise when the
      # Location header is missing/unparsable.
      def build_pending(response)
        location = response.location
        invoice_id = extract_invoice_id(location)
        if location.nil? || location.empty? || invoice_id.nil?
          raise Nfe::InvoiceProcessingError.new(
            "Resposta 202 sem Location utilizável: não é possível identificar a NF-e em processamento.",
            status_code: response.status, response_headers: response.headers
          )
        end
        ProductInvoicePending.new(invoice_id: invoice_id, location: location)
      end

      def extract_invoice_id(location)
        return nil if location.nil?

        match = location.match(%r{productinvoices/([a-z0-9-]+)}i)
        match ? match[1] : nil
      end
    end
  end
end
