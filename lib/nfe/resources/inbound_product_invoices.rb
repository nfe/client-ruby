# frozen_string_literal: true

require "json"
require "nfe/resources/abstract_resource"
require "nfe/resources/dto/inbound_settings"
require "nfe/resources/dto/inbound_invoice_metadata"

module Nfe
  module Resources
    # Inbound supplier NF-e (Nota Fiscal Eletrônica de fornecedor) resource for
    # the +:cte+ host family (+https://api.nfse.io+). Manages automatic NF-e
    # fetch via SEFAZ Distribuição DFe, reads received NF-e documents/events,
    # sends the recipient manifest (Manifestação do Destinatário) and reprocesses
    # webhooks.
    #
    # This is an inbound/query resource (settings + access-key lookups), not an
    # emission resource: there is no discriminated 202 +Pending+/+Issued+
    # contract here. The host carries no version segment, so paths embed +/v2+
    # literally and {#api_version} is +""+.
    #
    # There are two detail surfaces: the generic webhook-v1 path
    # (+.../inbound/{key}+) and the recommended webhook-v2 path
    # (+.../inbound/productinvoice/{key}+, which adds a +productInvoices+ array).
    #
    # @example Enable auto-fetch and manifest awareness of a received NF-e
    #   client.inbound_product_invoices.enable_auto_fetch(company_id: "co-1")
    #   client.inbound_product_invoices.manifest(company_id: "co-1", access_key: "3524...7890")
    class InboundProductInvoices < AbstractResource
      # Manifest event type — Ciência da Operação (awareness, default).
      MANIFEST_AWARENESS = 210_210
      # Manifest event type — Confirmação da Operação (confirmation).
      MANIFEST_CONFIRMATION = 210_220
      # Manifest event type — Operação não Realizada (operation not performed).
      MANIFEST_NOT_PERFORMED = 210_240

      protected

      def api_family
        :cte
      end

      # The +:cte+ host carries no version segment; +/v2+ is embedded per path.
      def api_version
        ""
      end

      public

      # Enable automatic NF-e distribution fetch for a company.
      #
      # @param company_id [String]
      # @param start_from_nsu [Integer, String, nil]
      # @param start_from_date [String, nil] ISO 8601 starting date.
      # @param environment_sefaz [String, nil] +"Production"+/+"Test"+.
      # @param automatic_manifesting [Hash, nil] auto-manifesting config.
      # @param webhook_version [String, Integer, nil] +"1"+/+"2"+.
      # @return [Nfe::InboundSettings]
      def enable_auto_fetch(company_id:, start_from_nsu: nil, start_from_date: nil,
                            environment_sefaz: nil, automatic_manifesting: nil, webhook_version: nil)
        id = Nfe::IdValidator.company_id(company_id)
        body = compact(
          "startFromNsu" => start_from_nsu, "startFromDate" => start_from_date,
          "environmentSEFAZ" => environment_sefaz, "automaticManifesting" => automatic_manifesting,
          "webhookVersion" => webhook_version
        )
        response = post("/v2/companies/#{id}/inbound/productinvoices",
                        body: json_body(body), headers: json_headers)
        hydrate(Nfe::InboundSettings, parse_json(response.body))
      end

      # Disable automatic NF-e distribution fetch for a company.
      #
      # @param company_id [String]
      # @return [Nfe::InboundSettings]
      def disable_auto_fetch(company_id:)
        id = Nfe::IdValidator.company_id(company_id)
        response = delete("/v2/companies/#{id}/inbound/productinvoices")
        hydrate(Nfe::InboundSettings, parse_json(response.body))
      end

      # Get the current automatic NF-e fetch settings.
      #
      # @param company_id [String]
      # @return [Nfe::InboundSettings]
      def get_settings(company_id:)
        id = Nfe::IdValidator.company_id(company_id)
        response = get("/v2/companies/#{id}/inbound/productinvoices")
        hydrate(Nfe::InboundSettings, parse_json(response.body))
      end

      # Get details of an inbound document by access key (webhook-v1 format).
      #
      # @param company_id [String]
      # @param access_key [String]
      # @return [Nfe::InboundInvoiceMetadata]
      def get_details(company_id:, access_key:)
        id, key = company_and_key(company_id, access_key)
        response = get("/v2/companies/#{id}/inbound/#{key}")
        hydrate(Nfe::InboundInvoiceMetadata, parse_json(response.body))
      end

      # Get details of an inbound NF-e by access key (webhook-v2 format,
      # recommended; adds the +product_invoices+ array).
      #
      # @param company_id [String]
      # @param access_key [String]
      # @return [Nfe::InboundInvoiceMetadata]
      def get_product_invoice_details(company_id:, access_key:)
        id, key = company_and_key(company_id, access_key)
        response = get("/v2/companies/#{id}/inbound/productinvoice/#{key}")
        hydrate(Nfe::InboundInvoiceMetadata, parse_json(response.body))
      end

      # Get details of an event related to an inbound document (webhook-v1).
      #
      # @param company_id [String]
      # @param access_key [String]
      # @param event_key [String]
      # @return [Nfe::InboundInvoiceMetadata]
      def get_event_details(company_id:, access_key:, event_key:)
        id, key, ev = company_key_event(company_id, access_key, event_key)
        response = get("/v2/companies/#{id}/inbound/#{key}/events/#{ev}")
        hydrate(Nfe::InboundInvoiceMetadata, parse_json(response.body))
      end

      # Get details of an event related to an inbound NF-e (webhook-v2).
      #
      # @param company_id [String]
      # @param access_key [String]
      # @param event_key [String]
      # @return [Nfe::InboundInvoiceMetadata]
      def get_product_invoice_event_details(company_id:, access_key:, event_key:)
        id, key, ev = company_key_event(company_id, access_key, event_key)
        response = get("/v2/companies/#{id}/inbound/productinvoice/#{key}/events/#{ev}")
        hydrate(Nfe::InboundInvoiceMetadata, parse_json(response.body))
      end

      # Download the XML of an inbound document by access key.
      #
      # @param company_id [String]
      # @param access_key [String]
      # @return [String] raw XML bytes (+ASCII-8BIT+).
      def get_xml(company_id:, access_key:)
        id, key = company_and_key(company_id, access_key)
        download("/v2/companies/#{id}/inbound/#{key}/xml", headers: xml_accept)
      end

      # Download the XML of an event related to an inbound document.
      #
      # @param company_id [String]
      # @param access_key [String]
      # @param event_key [String]
      # @return [String] raw XML bytes (+ASCII-8BIT+).
      def get_event_xml(company_id:, access_key:, event_key:)
        id, key, ev = company_key_event(company_id, access_key, event_key)
        download("/v2/companies/#{id}/inbound/#{key}/events/#{ev}/xml", headers: xml_accept)
      end

      # Download the PDF (DANFE) of an inbound NF-e by access key.
      #
      # @param company_id [String]
      # @param access_key [String]
      # @return [String] raw PDF bytes (+ASCII-8BIT+).
      def get_pdf(company_id:, access_key:)
        id, key = company_and_key(company_id, access_key)
        download("/v2/companies/#{id}/inbound/#{key}/pdf", headers: pdf_accept)
      end

      # Get the structured JSON representation of an inbound NF-e by access key.
      #
      # @param company_id [String]
      # @param access_key [String]
      # @return [Nfe::InboundInvoiceMetadata]
      def get_json(company_id:, access_key:)
        id, key = company_and_key(company_id, access_key)
        response = get("/v2/companies/#{id}/inbound/productinvoice/#{key}/json")
        hydrate(Nfe::InboundInvoiceMetadata, parse_json(response.body))
      end

      # Send the recipient manifest (Manifestação do Destinatário) for an NF-e.
      # +tp_event+ defaults to {MANIFEST_AWARENESS} (210210); the other codes are
      # {MANIFEST_CONFIRMATION} (210220) and {MANIFEST_NOT_PERFORMED} (210240).
      #
      # @param company_id [String]
      # @param access_key [String]
      # @param tp_event [Integer]
      # @return [String] the manifest response body.
      def manifest(company_id:, access_key:, tp_event: MANIFEST_AWARENESS)
        id, key = company_and_key(company_id, access_key)
        response = post("/v2/companies/#{id}/inbound/#{key}/manifest",
                        query: { tpEvent: tp_event })
        response.body || ""
      end

      # Reprocess the webhook for an inbound NF-e, identified by either a 44-digit
      # access key OR a numeric NSU. A bare NSU is not rejected as an invalid key.
      #
      # @param company_id [String]
      # @param access_key_or_nsu [String, Integer]
      # @return [Nfe::InboundInvoiceMetadata]
      def reprocess_webhook(company_id:, access_key_or_nsu:)
        id = Nfe::IdValidator.company_id(company_id)
        identifier = Nfe::IdValidator.presence!(access_key_or_nsu, "access_key_or_nsu")
        response = post("/v2/companies/#{id}/inbound/productinvoice/#{identifier}/processwebhook")
        hydrate(Nfe::InboundInvoiceMetadata, parse_json(response.body))
      end

      private

      def company_and_key(company_id, access_key)
        [Nfe::IdValidator.company_id(company_id), Nfe::IdValidator.access_key(access_key)]
      end

      def company_key_event(company_id, access_key, event_key)
        [Nfe::IdValidator.company_id(company_id), Nfe::IdValidator.access_key(access_key),
         Nfe::IdValidator.event_key(event_key)]
      end

      def json_headers
        { "Content-Type" => "application/json" }
      end

      def json_body(data)
        JSON.generate(data)
      end

      def xml_accept
        { "Accept" => "application/xml" }
      end

      def pdf_accept
        { "Accept" => "application/pdf" }
      end

      # Drop +nil+ values so optional fields are omitted from the body.
      def compact(hash)
        hash.compact
      end
    end
  end
end
