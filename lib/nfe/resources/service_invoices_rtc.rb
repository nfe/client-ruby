# frozen_string_literal: true

require "json"
require "nfe/resources/abstract_resource"
require "nfe/resources/dto/service_invoice"
require "nfe/resources/responses/service_invoice_rtc_pending"
require "nfe/resources/responses/service_invoice_rtc_issued"

module Nfe
  module Resources
    # RTC (Reforma Tributária do Consumo) service-invoice (NFS-e) emission
    # resource for the +:main+ host family (+https://api.nfe.io/v1/...+).
    #
    # RTC reuses the SAME endpoints as the classic {Nfe::Resources::ServiceInvoices}
    # resource (+/companies/{company_id}/serviceinvoices+). There is no
    # discriminator header or query parameter: the API selects the RTC document
    # layout from the PRESENCE of the +ibsCbs+ group in the create payload. When
    # +ibsCbs+ is absent the API falls back to the classic NFS-e layout.
    #
    # Emission is typically asynchronous: {#create} returns either a
    # {Nfe::Resources::ServiceInvoiceRtcPending} (HTTP 202, queued) or a
    # {Nfe::Resources::ServiceInvoiceRtcIssued} (HTTP 201, materialized). There is
    # no +create_and_wait+/+create_batch+ — poll {#retrieve} manually.
    #
    # @example RTC emission selected by the +ibsCbs+ group
    #   client.service_invoices_rtc.create(
    #     company_id: "co_1",
    #     data: { borrower: { ... }, servicesAmount: 100.0, ibsCbs: { cbs: { ... }, ibs: { ... } } }
    #   )
    class ServiceInvoicesRtc < AbstractResource
      protected

      def api_family
        :main
      end

      def api_version
        "v1"
      end

      public

      # Create (emit) an RTC service invoice. Returns a discriminated result: a
      # {ServiceInvoiceRtcPending} on HTTP 202 (queued, +invoice_id+ parsed from
      # the +Location+ header) or a {ServiceInvoiceRtcIssued} on HTTP 201
      # (materialized, hydrating {Nfe::ServiceInvoice}).
      #
      # +data+ is a Hash with camelCase keys (JSON-encoded as-is). The generated
      # +Nfe::Generated::ServiceInvoiceRtcV1::NFSeRequest+ DTO documents the
      # expected payload SHAPE (including the nested +ibsCbs+, +borrower+,
      # +location+, ... groups), but is NOT accepted as input: the generated DTOs
      # deserialize only (+from_api+) and have no camelCase re-serializer, so
      # passing the object would emit wrong keys. The RTC layout is selected by
      # the presence of the +ibsCbs+ group in +data+ — same endpoint as the
      # classic resource, no discriminator header/param.
      #
      # @param company_id [String]
      # @param data [Hash] invoice payload (camelCase keys); include +ibsCbs+ to
      #   select the RTC layout. Mirrors +ServiceInvoiceRtcV1::NFSeRequest+.
      # @param idempotency_key [String, nil] sent as the +Idempotency-Key+ header.
      # @param request_options [Nfe::RequestOptions, nil] per-call overrides.
      # @return [ServiceInvoiceRtcPending, ServiceInvoiceRtcIssued]
      # @raise [Nfe::InvoiceProcessingError] on a 202 with no/unparsable Location.
      def create(company_id:, data:, idempotency_key: nil, request_options: nil)
        cid = Nfe::IdValidator.company_id(company_id)
        response = post("/companies/#{cid}/serviceinvoices", body: json_body(data),
                                                             headers: json_headers,
                                                             idempotency_key: idempotency_key,
                                                             request_options: request_options)
        discriminate(response)
      end

      # Retrieve an RTC service invoice by id. The 201/GET body is the standard
      # NFS-e shape, hydrated into {Nfe::ServiceInvoice}.
      #
      # @param company_id [String]
      # @param invoice_id [String]
      # @return [Nfe::ServiceInvoice]
      # @raise [Nfe::NotFoundError] when the API responds 404 or an empty body.
      def retrieve(company_id:, invoice_id:)
        cid = Nfe::IdValidator.company_id(company_id)
        iid = Nfe::IdValidator.invoice_id(invoice_id)
        response = get("/companies/#{cid}/serviceinvoices/#{iid}")
        payload = parse_json(response.body)
        raise Nfe::NotFoundError, "nota de serviço #{iid} não encontrada" if payload.nil?

        hydrate(Nfe::ServiceInvoice, payload)
      end

      # Cancel an RTC service invoice (synchronous); returns the updated model.
      #
      # @param company_id [String]
      # @param invoice_id [String]
      # @return [Nfe::ServiceInvoice]
      def cancel(company_id:, invoice_id:)
        cid = Nfe::IdValidator.company_id(company_id)
        iid = Nfe::IdValidator.invoice_id(invoice_id)
        response = delete("/companies/#{cid}/serviceinvoices/#{iid}")
        hydrate(Nfe::ServiceInvoice, parse_json(response.body))
      end

      # Download the cancellation XML (ADN-only, available after the invoice
      # reaches the +Cancelled+ state). Returns the raw bytes (+ASCII-8BIT+).
      #
      # @param company_id [String]
      # @param invoice_id [String]
      # @return [String] XML bytes (ASCII-8BIT).
      # @raise [Nfe::NotFoundError] when the document is unavailable (404/empty).
      def download_cancellation_xml(company_id:, invoice_id:)
        cid = Nfe::IdValidator.company_id(company_id)
        iid = Nfe::IdValidator.invoice_id(invoice_id)
        bytes = download("/companies/#{cid}/serviceinvoices/#{iid}/cancellation-xml",
                         headers: { "Accept" => "application/xml" })
        raise Nfe::NotFoundError, "XML de cancelamento da nota #{iid} não encontrado" if bytes.empty?

        bytes
      end

      private

      def json_headers
        { "Content-Type" => "application/json" }
      end

      def json_body(data)
        JSON.generate(data)
      end

      # Interpret the emission response into the discriminated value object.
      def discriminate(response)
        return build_pending(response) if response.status == 202

        ServiceInvoiceRtcIssued.new(resource: hydrate(Nfe::ServiceInvoice, parse_json(response.body)))
      end

      # Build a {ServiceInvoiceRtcPending} from a 202 response, or raise when the
      # Location header is missing/unparsable.
      def build_pending(response)
        location = response.location
        invoice_id = extract_rtc_invoice_id(location)
        if location.nil? || location.empty? || invoice_id.nil?
          raise Nfe::InvoiceProcessingError.new(
            "Resposta 202 sem Location utilizável: não é possível identificar a NFS-e em processamento.",
            status_code: response.status, response_headers: response.headers
          )
        end
        ServiceInvoiceRtcPending.new(invoice_id: invoice_id, location: location)
      end

      # Extract the trailing id from a +Location+ path.
      def extract_rtc_invoice_id(location)
        return nil if location.nil?

        match = location.match(%r{serviceinvoices/([a-z0-9-]+)}i)
        match ? match[1] : nil
      end
    end
  end
end
