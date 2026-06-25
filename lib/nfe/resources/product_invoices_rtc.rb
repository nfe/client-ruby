# frozen_string_literal: true

require "json"
require "nfe/resources/abstract_resource"
require "nfe/resources/dto/nfe_file_resource"
require "nfe/generated"
require "nfe/resources/responses/product_invoice_rtc_pending"
require "nfe/resources/responses/product_invoice_rtc_issued"

module Nfe
  module Resources
    # RTC (Reforma Tributária do Consumo) product invoices (NF-e mod 55 / NFC-e
    # mod 65) resource for the +:cte+ host family (+https://api.nfse.io/v2/...+).
    # Full lifecycle: issue, list, retrieve, cancel, correction letters (CC-e),
    # disablement (inutilização) and file downloads, hydrating the RTC generated
    # DTOs in {Nfe::Generated::ProductInvoiceRtcV1}.
    #
    # This resource shares the SAME endpoints as the classic
    # {Nfe::Resources::ProductInvoices}. There is NO discriminator header or
    # query param: the RTC tax layout is selected by the API from the SHAPE of
    # the payload — specifically the presence of the item-level +IBSCBS+ group
    # (+items[].tax.IBSCBS+). NF-e (mod 55) vs NFC-e (mod 65) is likewise
    # inferred from the payload shape. Use this resource (vs the classic one)
    # when you want the RTC response DTOs hydrated.
    #
    # Emission is asynchronous (HTTP 202, queued; completion via webhook):
    # {#create}/{#create_with_state_tax} return either a
    # {Nfe::Resources::ProductInvoiceRtcPending} or a
    # {Nfe::Resources::ProductInvoiceRtcIssued}. There is no
    # +create_and_wait+/+create_batch+ — poll manually with {#retrieve} +
    # {Nfe::FlowStatus.terminal?}.
    #
    # NOTE: as with the classic resource, the download methods return a
    # {Nfe::NfeFileResource} (a URI to the file), NOT raw bytes — the API
    # responds with a JSON +{ uri }+ envelope.
    class ProductInvoicesRtc < AbstractResource
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

      # Issue an RTC product invoice (NF-e/NFC-e). Returns a discriminated
      # result: a {ProductInvoiceRtcPending} on HTTP 202 or a
      # {ProductInvoiceRtcIssued} (hydrating
      # {Nfe::Generated::ProductInvoiceRtcV1::InvoiceResource}) on 201.
      #
      # +data+ is a Hash with camelCase keys. The generated request DTO
      # {Nfe::Generated::ProductInvoiceRtcV1::ProductInvoiceRequest} documents
      # the expected payload SHAPE; it is NOT accepted as input (the generated
      # DTOs deserialize only and have no camelCase serialization path). The RTC
      # layout is selected by the presence of the item-level +IBSCBS+ group
      # (+items[].tax.IBSCBS+); NF-e (mod 55) vs NFC-e (mod 65) follows the
      # payload shape. Same endpoint as the classic resource.
      #
      # @param company_id [String]
      # @param data [Hash] invoice payload (camelCase keys per the API).
      # @param idempotency_key [String, nil] sent as the +Idempotency-Key+ header.
      # @param request_options [Nfe::RequestOptions, nil] per-call overrides.
      # @return [ProductInvoiceRtcPending, ProductInvoiceRtcIssued]
      def create(company_id:, data:, idempotency_key: nil, request_options: nil)
        cid = Nfe::IdValidator.company_id(company_id)
        response = post(base_path(cid), body: json_body(data), headers: json_headers,
                                        idempotency_key: idempotency_key,
                                        request_options: request_options)
        discriminate(response)
      end

      # Issue an RTC product invoice scoped to a state tax registration.
      #
      # +data+ is a Hash with camelCase keys (see {#create} for the payload
      # shape and RTC-layout selection notes).
      #
      # @param company_id [String]
      # @param state_tax_id [String]
      # @param data [Hash]
      # @param idempotency_key [String, nil]
      # @param request_options [Nfe::RequestOptions, nil]
      # @return [ProductInvoiceRtcPending, ProductInvoiceRtcIssued]
      def create_with_state_tax(company_id:, state_tax_id:, data:, idempotency_key: nil, request_options: nil)
        cid = Nfe::IdValidator.company_id(company_id)
        sid = Nfe::IdValidator.state_tax_id(state_tax_id)
        response = post("/v2/companies/#{cid}/statetaxes/#{sid}/productinvoices",
                        body: json_body(data), headers: json_headers,
                        idempotency_key: idempotency_key, request_options: request_options)
        discriminate(response)
      end

      # List RTC product invoices (cursor-style). +environment+ is REQUIRED.
      #
      # @param company_id [String]
      # @param environment [String] +"Production"+ or +"Test"+ (required).
      # @param starting_after [String, nil]
      # @param ending_before [String, nil]
      # @param limit [Integer, nil]
      # @param q [String, nil]
      # @return [Nfe::ListResponse] items hydrated as
      #   {Nfe::Generated::ProductInvoiceRtcV1::InvoiceResource}.
      # @raise [Nfe::InvalidRequestError] when +environment+ is missing.
      def list(company_id:, environment:, starting_after: nil, ending_before: nil, limit: nil, q: nil)
        cid = Nfe::IdValidator.company_id(company_id)
        require_environment(environment)
        query = list_query(starting_after: starting_after, ending_before: ending_before,
                           limit: limit, q: q).merge(environment: environment)
        response = get(base_path(cid), query: query)
        hydrate_list(Nfe::Generated::ProductInvoiceRtcV1::InvoiceResource,
                     parse_json(response.body), wrapper_key: "productInvoices")
      end

      # Retrieve an RTC product invoice by id.
      #
      # @param company_id [String]
      # @param invoice_id [String]
      # @return [Nfe::Generated::ProductInvoiceRtcV1::InvoiceResource, nil]
      # @raise [Nfe::NotFoundError] on HTTP 404.
      def retrieve(company_id:, invoice_id:)
        cid = Nfe::IdValidator.company_id(company_id)
        iid = Nfe::IdValidator.invoice_id(invoice_id)
        response = get("#{base_path(cid)}/#{iid}")
        hydrate(Nfe::Generated::ProductInvoiceRtcV1::InvoiceResource, parse_json(response.body))
      end

      # Cancel an RTC product invoice (async); +reason+ forwarded as a query
      # param. Hydrates
      # {Nfe::Generated::ProductInvoiceRtcV1::RequestCancellationResource}.
      #
      # @param company_id [String]
      # @param invoice_id [String]
      # @param reason [String, nil]
      # @return [Nfe::Generated::ProductInvoiceRtcV1::RequestCancellationResource, nil]
      def cancel(company_id:, invoice_id:, reason: nil)
        cid = Nfe::IdValidator.company_id(company_id)
        iid = Nfe::IdValidator.invoice_id(invoice_id)
        response = delete("#{base_path(cid)}/#{iid}", query: { reason: reason }.compact)
        hydrate(Nfe::Generated::ProductInvoiceRtcV1::RequestCancellationResource, parse_json(response.body))
      end

      # List items of an invoice. Hydrates
      # {Nfe::Generated::ProductInvoiceRtcV1::InvoiceItemsResource}.
      #
      # @param company_id [String]
      # @param invoice_id [String]
      # @return [Nfe::Generated::ProductInvoiceRtcV1::InvoiceItemsResource, nil]
      def list_items(company_id:, invoice_id:)
        cid = Nfe::IdValidator.company_id(company_id)
        iid = Nfe::IdValidator.invoice_id(invoice_id)
        response = get("#{base_path(cid)}/#{iid}/items")
        hydrate(Nfe::Generated::ProductInvoiceRtcV1::InvoiceItemsResource, parse_json(response.body))
      end

      # List fiscal events of an invoice. Hydrates
      # {Nfe::Generated::ProductInvoiceRtcV1::InvoiceEventsResource}.
      #
      # @param company_id [String]
      # @param invoice_id [String]
      # @return [Nfe::Generated::ProductInvoiceRtcV1::InvoiceEventsResource, nil]
      def list_events(company_id:, invoice_id:)
        cid = Nfe::IdValidator.company_id(company_id)
        iid = Nfe::IdValidator.invoice_id(invoice_id)
        response = get("#{base_path(cid)}/#{iid}/events")
        hydrate(Nfe::Generated::ProductInvoiceRtcV1::InvoiceEventsResource, parse_json(response.body))
      end

      # DANFE PDF file resource (URI, not bytes). +force+ regenerates the PDF.
      #
      # @return [Nfe::NfeFileResource]
      def download_pdf(company_id:, invoice_id:, force: false)
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
      # @return [Nfe::Generated::ProductInvoiceRtcV1::RequestCancellationResource, nil]
      # @raise [Nfe::InvalidRequestError] when +reason+ length is out of range.
      def send_correction_letter(company_id:, invoice_id:, reason:)
        cid = Nfe::IdValidator.company_id(company_id)
        iid = Nfe::IdValidator.invoice_id(invoice_id)
        validate_correction_reason(reason)
        response = put("#{base_path(cid)}/#{iid}/correctionletter",
                       body: json_body({ reason: reason }), headers: json_headers)
        hydrate(Nfe::Generated::ProductInvoiceRtcV1::RequestCancellationResource, parse_json(response.body))
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

      # Disable (inutilizar) a single invoice (async). +reason+ optional;
      # forwarded as a query param. Hydrates
      # {Nfe::Generated::ProductInvoiceRtcV1::DisablementResource}.
      #
      # @param company_id [String]
      # @param invoice_id [String]
      # @param reason [String, nil]
      # @return [Nfe::Generated::ProductInvoiceRtcV1::DisablementResource, nil]
      def disable(company_id:, invoice_id:, reason: nil)
        cid = Nfe::IdValidator.company_id(company_id)
        iid = Nfe::IdValidator.invoice_id(invoice_id)
        response = post("#{base_path(cid)}/#{iid}/disablement", query: { reason: reason }.compact)
        hydrate(Nfe::Generated::ProductInvoiceRtcV1::DisablementResource, parse_json(response.body))
      end

      # Disable a range of invoice numbers (single number = same begin/last).
      # +data+ is a Hash with camelCase keys.
      #
      # @param company_id [String]
      # @param data [Hash] +{ environment, serie, state, beginNumber, lastNumber, reason? }+.
      # @return [Nfe::Generated::ProductInvoiceRtcV1::DisablementResource, nil]
      def disable_range(company_id:, data:)
        cid = Nfe::IdValidator.company_id(company_id)
        response = post("#{base_path(cid)}/disablement", body: json_body(data), headers: json_headers)
        hydrate(Nfe::Generated::ProductInvoiceRtcV1::DisablementResource, parse_json(response.body))
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

      def list_query(starting_after:, ending_before:, limit:, q:)
        {
          startingAfter: starting_after, endingBefore: ending_before,
          limit: limit, q: q
        }.compact
      end

      def validate_correction_reason(reason)
        length = reason.to_s.length
        return if length.between?(15, 1000)

        raise Nfe::InvalidRequestError,
              "motivo da carta de correção deve conter entre 15 e 1000 caracteres"
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

        ProductInvoiceRtcIssued.new(
          resource: hydrate(Nfe::Generated::ProductInvoiceRtcV1::InvoiceResource, parse_json(response.body))
        )
      end

      # Build a {ProductInvoiceRtcPending} from a 202 response, or raise when the
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
        ProductInvoiceRtcPending.new(invoice_id: invoice_id, location: location)
      end

      def extract_invoice_id(location)
        return nil if location.nil?

        match = location.match(%r{productinvoices/([a-z0-9-]+)}i)
        match ? match[1] : nil
      end
    end
  end
end
