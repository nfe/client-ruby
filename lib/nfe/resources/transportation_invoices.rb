# frozen_string_literal: true

require "json"
require "nfe/resources/abstract_resource"
require "nfe/resources/dto/inbound_settings"
require "nfe/resources/dto/inbound_invoice_metadata"

module Nfe
  module Resources
    # Inbound CT-e (Conhecimento de Transporte Eletrônico) resource for the
    # +:cte+ host family (+https://api.nfse.io+). Manages automatic CT-e fetch
    # via SEFAZ Distribuição DFe and reads received CT-e documents/events by
    # 44-digit access key.
    #
    # This is an inbound/query resource (settings + access-key lookups), not an
    # emission resource: there is no discriminated 202 +Pending+/+Issued+
    # contract here. The host already carries no version segment, so paths embed
    # +/v2+ literally and {#api_version} is +""+.
    #
    # @example Enable auto-fetch and read a received CT-e
    #   client.transportation_invoices.enable(company_id: "co-1")
    #   cte = client.transportation_invoices.retrieve(
    #     company_id: "co-1",
    #     access_key: "3524...7890"
    #   )
    class TransportationInvoices < AbstractResource
      protected

      def api_family
        :cte
      end

      # The +:cte+ host carries no version segment; +/v2+ is embedded per path.
      def api_version
        ""
      end

      public

      # Enable automatic CT-e search for a company via Distribuição DFe.
      #
      # @param company_id [String]
      # @param start_from_nsu [Integer, String, nil] optional starting NSU.
      # @param start_from_date [String, nil] optional starting date (ISO 8601).
      # @return [Nfe::InboundSettings]
      def enable(company_id:, start_from_nsu: nil, start_from_date: nil)
        id = Nfe::IdValidator.company_id(company_id)
        body = compact("startFromNsu" => start_from_nsu, "startFromDate" => start_from_date)
        response = post("/v2/companies/#{id}/inbound/transportationinvoices",
                        body: json_body(body), headers: json_headers)
        hydrate(Nfe::InboundSettings, parse_json(response.body))
      end

      # Disable automatic CT-e search for a company.
      #
      # @param company_id [String]
      # @return [Nfe::InboundSettings]
      def disable(company_id:)
        id = Nfe::IdValidator.company_id(company_id)
        response = delete("/v2/companies/#{id}/inbound/transportationinvoices")
        hydrate(Nfe::InboundSettings, parse_json(response.body))
      end

      # Get the current automatic CT-e search settings.
      #
      # @param company_id [String]
      # @return [Nfe::InboundSettings]
      def get_settings(company_id:)
        id = Nfe::IdValidator.company_id(company_id)
        response = get("/v2/companies/#{id}/inbound/transportationinvoices")
        hydrate(Nfe::InboundSettings, parse_json(response.body))
      end

      # Retrieve CT-e metadata by its 44-digit access key (normalized).
      #
      # @param company_id [String]
      # @param access_key [String] 44-digit key; separators are stripped.
      # @return [Nfe::InboundInvoiceMetadata]
      def retrieve(company_id:, access_key:)
        id = Nfe::IdValidator.company_id(company_id)
        key = Nfe::IdValidator.access_key(access_key)
        response = get("/v2/companies/#{id}/inbound/#{key}")
        hydrate(Nfe::InboundInvoiceMetadata, parse_json(response.body))
      end

      # Download the CT-e XML by access key.
      #
      # @param company_id [String]
      # @param access_key [String]
      # @return [String] raw XML bytes (+ASCII-8BIT+).
      def download_xml(company_id:, access_key:)
        id = Nfe::IdValidator.company_id(company_id)
        key = Nfe::IdValidator.access_key(access_key)
        download("/v2/companies/#{id}/inbound/#{key}/xml", headers: xml_accept)
      end

      # Retrieve the metadata of an event related to a received CT-e.
      #
      # @param company_id [String]
      # @param access_key [String]
      # @param event_key [String]
      # @return [Nfe::InboundInvoiceMetadata]
      def get_event(company_id:, access_key:, event_key:)
        id = Nfe::IdValidator.company_id(company_id)
        key = Nfe::IdValidator.access_key(access_key)
        ev = Nfe::IdValidator.event_key(event_key)
        response = get("/v2/companies/#{id}/inbound/#{key}/events/#{ev}")
        hydrate(Nfe::InboundInvoiceMetadata, parse_json(response.body))
      end

      # Download the XML of a CT-e event.
      #
      # @param company_id [String]
      # @param access_key [String]
      # @param event_key [String]
      # @return [String] raw XML bytes (+ASCII-8BIT+).
      def download_event_xml(company_id:, access_key:, event_key:)
        id = Nfe::IdValidator.company_id(company_id)
        key = Nfe::IdValidator.access_key(access_key)
        ev = Nfe::IdValidator.event_key(event_key)
        download("/v2/companies/#{id}/inbound/#{key}/events/#{ev}/xml", headers: xml_accept)
      end

      private

      def json_headers
        { "Content-Type" => "application/json" }
      end

      def json_body(data)
        JSON.generate(data)
      end

      def xml_accept
        { "Accept" => "application/xml" }
      end

      # Drop +nil+ values so optional fields are omitted from the body.
      def compact(hash)
        hash.compact
      end
    end
  end
end
