# frozen_string_literal: true

require "nfe/resources/abstract_resource"
require "nfe/resources/dto/consumer_invoice_query/tax_coupon"

module Nfe
  module Resources
    # Query (consulta) of consumer invoices — NFC-e tax coupons (CFe-SAT) — by
    # access key, served by the +:nfe_query+ family (+nfe.api.nfe.io+, +/v1+,
    # +/coupon/+ path).
    #
    # This is DISTINCT from {Nfe::Resources::ConsumerInvoices} (NFC-e emission,
    # +add-invoice-resources+): different host and API version. Here we only
    # retrieve and download an already-issued coupon.
    class ConsumerInvoiceQuery < AbstractResource
      protected

      def api_family = :nfe_query

      # The version segment (+v1+) is embedded in the request path, so no version
      # prefix is added by the base class.
      def api_version = ""

      public

      # Retrieve a consumer-invoice tax coupon by its access key.
      #
      # @param access_key [String] the 44-digit NFC-e access key (normalized).
      # @return [Nfe::TaxCoupon]
      def retrieve(access_key)
        key = Nfe::IdValidator.access_key(access_key)
        hydrate(Nfe::TaxCoupon, parse_json(get("/v1/consumerinvoices/coupon/#{key}").body))
      end

      # Download the raw XML for a consumer-invoice tax coupon.
      #
      # @param access_key [String] the 44-digit NFC-e access key (normalized).
      # @return [String] the XML document bytes (+ASCII-8BIT+).
      def download_xml(access_key)
        key = Nfe::IdValidator.access_key(access_key)
        download("/v1/consumerinvoices/coupon/#{key}.xml", headers: { "Accept" => "application/xml" })
      end
    end
  end
end
