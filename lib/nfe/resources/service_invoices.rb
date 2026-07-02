# frozen_string_literal: true

require "json"
require "nfe/resources/abstract_resource"
require "nfe/resources/dto/service_invoice"
require "nfe/resources/responses/service_invoice_pending"
require "nfe/resources/responses/service_invoice_issued"

module Nfe
  module Resources
    # Service invoices (NFS-e) resource for the +:main+ host family
    # (+https://api.nfe.io/v1/...+). This is the canonical emission resource of
    # the platform.
    #
    # Emission is typically asynchronous: {#create} returns either a
    # {Nfe::Resources::ServiceInvoicePending} (HTTP 202, queued) or a
    # {Nfe::Resources::ServiceInvoiceIssued} (HTTP 201, materialized). There is
    # no +create_and_wait+/+create_batch+ in v1.0 — poll manually:
    #
    #   result = client.service_invoices.create(company_id: id, data: payload)
    #   if result.pending?
    #     loop do
    #       status = client.service_invoices.get_status(company_id: id, invoice_id: result.invoice_id)
    #       break if status.complete?
    #       sleep 2
    #     end
    #   end
    #
    # @example
    #   client.service_invoices.create(company_id: "co_1", data: { borrower: {...}, ... })
    class ServiceInvoices < AbstractResource
      # Derived status snapshot returned by {ServiceInvoices#get_status} without
      # issuing an extra HTTP call.
      class StatusResult < Data.define(:status, :invoice, :complete, :failed)
        # @return [Boolean] true when the flow status is terminal.
        def complete?
          complete
        end

        # @return [Boolean] true when the flow status is IssueFailed/CancelFailed.
        def failed?
          failed
        end
      end

      FAILED_STATUSES = %w[IssueFailed CancelFailed].freeze

      protected

      def api_family
        :main
      end

      public

      # Create (emit) a service invoice. Returns a discriminated result: a
      # {ServiceInvoicePending} on HTTP 202 (queued, +invoice_id+ parsed from the
      # +Location+ header) or a {ServiceInvoiceIssued} on HTTP 201 (materialized).
      #
      # @param company_id [String]
      # @param data [Hash] invoice payload (camelCase keys per the API).
      # @param idempotency_key [String, nil] sent as the +Idempotency-Key+ header.
      # @param request_options [Nfe::RequestOptions, nil] per-call overrides.
      # @return [ServiceInvoicePending, ServiceInvoiceIssued]
      # @raise [Nfe::InvoiceProcessingError] on a 202 with no/unparsable Location.
      def create(company_id:, data:, idempotency_key: nil, request_options: nil)
        cid = Nfe::IdValidator.company_id(company_id)
        response = post("/companies/#{cid}/serviceinvoices", body: json_body(data),
                                                             headers: json_headers,
                                                             idempotency_key: idempotency_key,
                                                             request_options: request_options)
        discriminate(response)
      end

      # List service invoices (page-style pagination plus date filters).
      #
      # @param company_id [String]
      # @param options [Hash] +page_index+, +page_count+, +issued_begin+,
      #   +issued_end+, +created_begin+, +created_end+, +has_totals+.
      # @return [Nfe::ListResponse]
      def list(company_id:, **options)
        cid = Nfe::IdValidator.company_id(company_id)
        response = get("/companies/#{cid}/serviceinvoices", query: list_query(options))
        hydrate_list(Nfe::ServiceInvoice, parse_json(response.body), wrapper_key: "serviceInvoices")
      end

      # Retrieve a service invoice by id.
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

      # Cancel a service invoice (synchronous); returns the updated model.
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

      # E-mail the invoice to the borrower. No e-mail list argument (Node parity).
      #
      # @param company_id [String]
      # @param invoice_id [String]
      # @return [Hash] +{ sent:, message: }+.
      def send_email(company_id:, invoice_id:)
        cid = Nfe::IdValidator.company_id(company_id)
        iid = Nfe::IdValidator.invoice_id(invoice_id)
        response = put("/companies/#{cid}/serviceinvoices/#{iid}/sendemail")
        payload = parse_json(response.body) || {}
        { sent: payload.fetch("sent", response.success?), message: payload["message"] }
      end

      # Download the invoice PDF (or the company ZIP when +invoice_id+ is nil).
      #
      # @param company_id [String]
      # @param invoice_id [String, nil]
      # @return [String] PDF/ZIP bytes (ASCII-8BIT).
      def download_pdf(company_id:, invoice_id: nil)
        download_document(company_id: company_id, invoice_id: invoice_id,
                          ext: "pdf", accept: "application/pdf")
      end

      # Download the invoice XML (or the company ZIP when +invoice_id+ is nil).
      #
      # @param company_id [String]
      # @param invoice_id [String, nil]
      # @return [String] XML/ZIP bytes (ASCII-8BIT).
      def download_xml(company_id:, invoice_id: nil)
        download_document(company_id: company_id, invoice_id: invoice_id,
                          ext: "xml", accept: "application/xml")
      end

      # Status snapshot derived from {#retrieve} (Node parity — no extra HTTP).
      #
      # @param company_id [String]
      # @param invoice_id [String]
      # @return [StatusResult]
      def get_status(company_id:, invoice_id:)
        invoice = retrieve(company_id: company_id, invoice_id: invoice_id)
        status = invoice&.flow_status || "WaitingSend"
        StatusResult.new(
          status: status, invoice: invoice,
          complete: Nfe::FlowStatus.terminal?(status),
          failed: FAILED_STATUSES.include?(status)
        )
      end

      private

      def json_headers
        { "Content-Type" => "application/json" }
      end

      def json_body(data)
        JSON.generate(data)
      end

      # Map snake_case list options onto the API's camelCase query parameters,
      # dropping nil values.
      def list_query(options)
        {
          pageIndex: options[:page_index], pageCount: options[:page_count],
          issuedBegin: options[:issued_begin], issuedEnd: options[:issued_end],
          createdBegin: options[:created_begin], createdEnd: options[:created_end],
          hasTotals: options[:has_totals]
        }.compact
      end

      # GET the single-invoice or bulk document path and return binary bytes.
      def download_document(company_id:, invoice_id:, ext:, accept:)
        cid = Nfe::IdValidator.company_id(company_id)
        path = if invoice_id.nil?
                 "/companies/#{cid}/serviceinvoices/#{ext}"
               else
                 iid = Nfe::IdValidator.invoice_id(invoice_id)
                 "/companies/#{cid}/serviceinvoices/#{iid}/#{ext}"
               end
        download(path, headers: { "Accept" => accept })
      end

      # Interpret the emission response into the discriminated value object.
      def discriminate(response)
        return build_pending(response) if response.status == 202

        ServiceInvoiceIssued.new(resource: hydrate(Nfe::ServiceInvoice, parse_json(response.body)))
      end

      # Build a {ServiceInvoicePending} from a 202 response, or raise when the
      # Location header is missing/unparsable.
      def build_pending(response)
        location = response.location
        invoice_id = extract_invoice_id(location)
        if location.nil? || location.empty? || invoice_id.nil?
          raise Nfe::InvoiceProcessingError.new(
            "Resposta 202 sem Location utilizável: não é possível identificar a NFS-e em processamento.",
            status_code: response.status, response_headers: response.headers
          )
        end
        ServiceInvoicePending.new(invoice_id: invoice_id, location: location)
      end

      # Extract the trailing id from a +Location+ path.
      def extract_invoice_id(location)
        return nil if location.nil?

        match = location.match(%r{serviceinvoices/([a-z0-9-]+)}i)
        match ? match[1] : nil
      end
    end
  end
end
