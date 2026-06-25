# frozen_string_literal: true

require "json"
require "nfe/resources/abstract_resource"
require "nfe/resources/dto/consumer_invoice"
require "nfe/resources/responses/consumer_invoice_pending"
require "nfe/resources/responses/consumer_invoice_issued"

module Nfe
  module Resources
    # Consumer invoices (NFC-e — Nota Fiscal de Consumidor Eletrônica).
    #
    # Hosted at +https://api.nfse.io+ under +/v2+ (the +:cte+ family), backed by
    # the paths exposed in +nf-consumidor-v2.yaml+.
    #
    # == Parity-plus
    # This resource is a *parity-plus* addition: the Node.js SDK deliberately
    # does NOT expose NFC-e emission (it covers only the read-only
    # +consumerInvoiceQuery+). The NFE.io API has supported the full NFC-e
    # lifecycle since v2, so this Ruby SDK extends beyond Node parity — useful
    # for PoS and e-commerce integrations.
    #
    # == Intentional omissions (grounded in Brazilian fiscal law)
    # Unlike {Nfe::Resources::ProductInvoices} (NF-e), this resource does NOT
    # define:
    # * +send_correction_letter+ — the Carta de Correção Eletrônica (CC-e)
    #   instrument applies only to NF-e/CT-e, never to NFC-e.
    # * +download_epec_xml+ — there is no EPEC (Evento Prévio de Emissão em
    #   Contingência) for NFC-e.
    # * a per-invoice +disable+ — NFC-e supports only *collective* inutilization
    #   of a number range via {#disable_range}, not per-document disablement.
    # Calling any of these raises +NoMethodError+.
    #
    # == Emission contract
    # {#create} and {#create_with_state_tax} return a discriminated result:
    # {Nfe::Resources::ConsumerInvoicePending} on HTTP 202 (async) or
    # {Nfe::Resources::ConsumerInvoiceIssued} on HTTP 201/200 (sync). Both accept
    # an optional +idempotency_key:+ (sent as the +Idempotency-Key+ header; the
    # SDK never auto-retries, so re-invoking with the SAME key after a timeout
    # lets the server deduplicate) and +request_options:+ (per-call
    # multi-tenant overrides). +create_and_wait+/+create_batch+ are deferred:
    # poll manually with +result.pending?+ + {Nfe::FlowStatus.terminal?}.
    #
    # @example Emit an NFC-e and handle the discriminated result
    #   result = client.consumer_invoices.create(company_id: id, data: payload)
    #   case result
    #   in Nfe::Resources::ConsumerInvoicePending => p then poll(p.invoice_id)
    #   in Nfe::Resources::ConsumerInvoiceIssued  => i then i.resource
    #   end
    class ConsumerInvoices < AbstractResource
      # Wrapper key for the list envelope.
      ENVELOPE = "consumerInvoices"

      protected

      def api_family
        :cte
      end

      # The +:cte+ host (+api.nfse.io+) does not bake in a version, so this
      # resource supplies the +/v2+ segment itself.
      def api_version
        "v2"
      end

      public

      # Emit an NFC-e. Returns {ConsumerInvoicePending} (HTTP 202) or
      # {ConsumerInvoiceIssued} (HTTP 201/200).
      #
      # @param company_id [String]
      # @param data [Hash] NFC-e payload (camelCase keys per the API).
      # @param idempotency_key [String, nil] sent as +Idempotency-Key+.
      # @param request_options [Nfe::RequestOptions, nil] per-call overrides.
      # @return [ConsumerInvoicePending, ConsumerInvoiceIssued]
      def create(company_id:, data:, idempotency_key: nil, request_options: nil)
        id = Nfe::IdValidator.company_id(company_id)
        response = post("/companies/#{id}/consumerinvoices", body: json_body(data),
                                                             headers: json_headers,
                                                             idempotency_key: idempotency_key,
                                                             request_options: request_options)
        discriminate(response)
      end

      # Emit an NFC-e scoped to a specific state-tax registration.
      #
      # @param company_id [String]
      # @param state_tax_id [String]
      # @param data [Hash]
      # @param idempotency_key [String, nil]
      # @param request_options [Nfe::RequestOptions, nil]
      # @return [ConsumerInvoicePending, ConsumerInvoiceIssued]
      def create_with_state_tax(company_id:, state_tax_id:, data:, idempotency_key: nil, request_options: nil)
        cid = Nfe::IdValidator.company_id(company_id)
        sid = Nfe::IdValidator.state_tax_id(state_tax_id)
        response = post("/companies/#{cid}/statetaxes/#{sid}/consumerinvoices",
                        body: json_body(data), headers: json_headers,
                        idempotency_key: idempotency_key, request_options: request_options)
        discriminate(response)
      end

      # List NFC-e for a company (cursor pagination; wrapper +consumerInvoices+).
      #
      # @param company_id [String]
      # @param options [Hash] cursor query params (+starting_after+, +limit+...).
      # @return [Nfe::ListResponse]
      def list(company_id:, **options)
        id = Nfe::IdValidator.company_id(company_id)
        response = get("/companies/#{id}/consumerinvoices", query: options)
        hydrate_list(Nfe::ConsumerInvoice, parse_json(response.body), wrapper_key: ENVELOPE)
      end

      # Retrieve a single NFC-e by id.
      #
      # @return [Nfe::ConsumerInvoice]
      def retrieve(company_id:, invoice_id:)
        cid, iid = validate_pair(company_id, invoice_id)
        response = get("/companies/#{cid}/consumerinvoices/#{iid}")
        hydrate(Nfe::ConsumerInvoice, parse_json(response.body))
      end

      # Cancel an NFC-e (synchronous); returns the updated model.
      #
      # @return [Nfe::ConsumerInvoice]
      def cancel(company_id:, invoice_id:)
        cid, iid = validate_pair(company_id, invoice_id)
        response = delete("/companies/#{cid}/consumerinvoices/#{iid}")
        hydrate(Nfe::ConsumerInvoice, parse_json(response.body))
      end

      # List the line items of an NFC-e.
      #
      # @return [Array<Hash>]
      def list_items(company_id:, invoice_id:)
        cid, iid = validate_pair(company_id, invoice_id)
        response = get("/companies/#{cid}/consumerinvoices/#{iid}/items")
        unwrap_collection(parse_json(response.body), "items")
      end

      # List the events of an NFC-e.
      #
      # @return [Array<Hash>]
      def list_events(company_id:, invoice_id:)
        cid, iid = validate_pair(company_id, invoice_id)
        response = get("/companies/#{cid}/consumerinvoices/#{iid}/events")
        unwrap_collection(parse_json(response.body), "events")
      end

      # Download the DANFE NFC-e PDF as binary bytes (unlike ProductInvoices,
      # which returns a URI).
      #
      # @return [String] +ASCII-8BIT+ PDF bytes.
      def download_pdf(company_id:, invoice_id:)
        cid, iid = validate_pair(company_id, invoice_id)
        download("/companies/#{cid}/consumerinvoices/#{iid}/pdf",
                 headers: { "Accept" => "application/pdf" })
      end

      # Download the authorized NFC-e XML as binary bytes.
      #
      # @return [String] +ASCII-8BIT+ XML bytes.
      def download_xml(company_id:, invoice_id:)
        cid, iid = validate_pair(company_id, invoice_id)
        download("/companies/#{cid}/consumerinvoices/#{iid}/xml",
                 headers: { "Accept" => "application/xml" })
      end

      # Download the rejection XML (sefaz refusal) as binary bytes.
      #
      # @return [String] +ASCII-8BIT+ XML bytes.
      def download_rejection_xml(company_id:, invoice_id:)
        cid, iid = validate_pair(company_id, invoice_id)
        download("/companies/#{cid}/consumerinvoices/#{iid}/xml/rejection",
                 headers: { "Accept" => "application/xml" })
      end

      # Collectively inutilize a range of NFC-e numbers. NFC-e supports only
      # collective inutilization (no per-invoice disablement).
      #
      # @param company_id [String]
      # @param data [Hash] +{ environment, serie, state, begin_number, last_number, reason? }+.
      # @return [Hash] the parsed disablement result.
      def disable_range(company_id:, data:)
        id = Nfe::IdValidator.company_id(company_id)
        response = post("/companies/#{id}/consumerinvoices/disablement",
                        body: json_body(data), headers: json_headers)
        parse_json(response.body) || {}
      end

      private

      # Validate a (company_id, invoice_id) pair, returning both normalized.
      def validate_pair(company_id, invoice_id)
        [Nfe::IdValidator.company_id(company_id), Nfe::IdValidator.invoice_id(invoice_id)]
      end

      # Interpret an emission response into the discriminated NFC-e result.
      def discriminate(response)
        return issued_result(response) unless response.status == 202

        location = response.location
        if location.nil? || location.empty?
          raise Nfe::InvoiceProcessingError.new(
            "Resposta 202 sem cabeçalho Location: não é possível identificar a NFC-e em processamento.",
            status_code: response.status, response_headers: response.headers
          )
        end
        ConsumerInvoicePending.new(invoice_id: extract_invoice_id(location), location: location)
      end

      def issued_result(response)
        invoice = hydrate(Nfe::ConsumerInvoice, parse_json(response.body))
        ConsumerInvoiceIssued.new(resource: invoice)
      end

      # Extract the trailing id from a +Location+ path.
      def extract_invoice_id(location)
        match = location.match(%r{/([a-z0-9-]+)\z}i)
        match ? match[1] : nil
      end

      # Unwrap a collection envelope, tolerating a bare array or a wrapped one.
      def unwrap_collection(payload, key)
        return payload if payload.is_a?(Array)
        return [] unless payload.is_a?(Hash)

        wrapped = payload[key] || payload[key.to_sym]
        wrapped.is_a?(Array) ? wrapped : []
      end

      def json_headers
        { "Content-Type" => "application/json" }
      end

      def json_body(data)
        JSON.generate(data)
      end
    end
  end
end
