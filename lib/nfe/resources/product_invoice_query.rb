# frozen_string_literal: true

require "nfe/resources/abstract_resource"
require "nfe/resources/dto/product_invoice_query/product_invoice_details"
require "nfe/resources/dto/product_invoice_query/product_invoice_events_response"

module Nfe
  module Resources
    # Read-only queries against the NF-e distribution/query API
    # (+https://nfe.api.nfe.io+). The version segment is embedded in the request
    # path, so +api_version+ is +""+.
    class ProductInvoiceQuery < AbstractResource
      # Fetch the details of a product invoice (NF-e) by its access key. The key
      # is normalized to 44 digits before the request is issued (fail-fast).
      #
      # @param access_key [String] the 44-digit NF-e access key.
      # @return [Nfe::ProductInvoiceDetails, nil]
      def retrieve(access_key)
        key = Nfe::IdValidator.access_key(access_key)
        response = get("/v2/productinvoices/#{key}")
        hydrate(Nfe::ProductInvoiceDetails, parse_json(response.body))
      end

      # Download the PDF (DANFE) of a product invoice by its access key.
      #
      # @param access_key [String] the 44-digit NF-e access key.
      # @return [String] the PDF bytes (+ASCII-8BIT+).
      def download_pdf(access_key)
        key = Nfe::IdValidator.access_key(access_key)
        download("/v2/productinvoices/#{key}.pdf", headers: { "Accept" => "application/pdf" })
      end

      # Download the XML of a product invoice by its access key.
      #
      # @param access_key [String] the 44-digit NF-e access key.
      # @return [String] the XML bytes (+ASCII-8BIT+).
      def download_xml(access_key)
        key = Nfe::IdValidator.access_key(access_key)
        download("/v2/productinvoices/#{key}.xml", headers: { "Accept" => "application/xml" })
      end

      # List the events (eventos) associated with a product invoice by its
      # access key.
      #
      # @param access_key [String] the 44-digit NF-e access key.
      # @return [Nfe::ProductInvoiceEventsResponse, nil]
      def list_events(access_key)
        key = Nfe::IdValidator.access_key(access_key)
        response = get("/v2/productinvoices/events/#{key}")
        hydrate(Nfe::ProductInvoiceEventsResponse, parse_json(response.body))
      end

      protected

      def api_family = :nfe_query

      # This family's host embeds the version in the path, so no version segment
      # is prefixed to the request path.
      def api_version = ""
    end
  end
end
