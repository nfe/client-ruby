# frozen_string_literal: true

module Nfe
  # Immutable value object for the details of a product invoice (NF-e) fetched
  # from the +nfe.api.nfe.io+ distribution/query API by its access key
  # (+GET /v2/productinvoices/{accessKey}+).
  #
  # Hand-written (the +consulta_nfe_distribuicao_v1+ generated schema does not
  # cover this pragmatic shape). {from_api} maps the API camelCase keys onto the
  # snake_case members, hydrates the nested value objects, drops unknown keys,
  # and is nil-tolerant (+from_api(nil)+ returns +nil+). All fields are optional.
  #
  # The access key is NOT a body field — it is the path parameter the caller
  # already holds — so it is intentionally not exposed here. +current_status+ is
  # the real top-level field (+currentStatus+, enum +unknown+/+authorized+/
  # +canceled+). The nested objects ({Issuer}, {Buyer}, {Totals}) keep only a
  # pragmatic subset of the most common fields; +items+ is kept as the raw
  # payload array (free-form line bodies), normalized to +[]+ when missing.
  class ProductInvoiceDetails < Data.define(
    :current_status,
    :state_code,
    :check_code,
    :operation_nature,
    :serie,
    :number,
    :issued_on,
    :operation_on,
    :issuer,
    :buyer,
    :totals,
    :items
  )
    # Issuer (emitente / emit) of the invoice.
    class Issuer < Data.define(:federal_tax_number, :name, :trade_name, :state_tax_number)
      def self.from_api(payload)
        return nil if payload.nil?

        new(
          federal_tax_number: payload["federalTaxNumber"]&.to_s,
          name: payload["name"],
          trade_name: payload["tradeName"],
          state_tax_number: payload["stateTaxNumber"]&.to_s
        )
      end
    end

    # Buyer (destinatário / dest) of the invoice.
    class Buyer < Data.define(:federal_tax_number, :name, :state_tax_number, :email)
      def self.from_api(payload)
        return nil if payload.nil?

        new(
          federal_tax_number: payload["federalTaxNumber"]&.to_s,
          name: payload["name"],
          state_tax_number: payload["stateTaxNumber"]&.to_s,
          email: payload["email"]
        )
      end
    end

    # Monetary totals of the invoice (the +icms+ subtotal group of +total+).
    class Totals < Data.define(:product_amount, :invoice_amount, :discount_amount, :icms_amount)
      def self.from_api(payload)
        return nil if payload.nil?

        icms = payload["icms"] || {}
        new(
          product_amount: icms["productAmount"],
          invoice_amount: icms["invoiceAmount"],
          discount_amount: icms["discountAmount"],
          icms_amount: icms["icmsAmount"]
        )
      end
    end

    # Build a {Nfe::ProductInvoiceDetails} from an API payload.
    #
    # @param payload [Hash, nil] the parsed invoice object.
    # @return [Nfe::ProductInvoiceDetails, nil] +nil+ when +payload+ is +nil+.
    def self.from_api(payload)
      return nil if payload.nil?

      new(
        current_status: payload["currentStatus"],
        state_code: payload["stateCode"],
        check_code: payload["checkCode"]&.to_s,
        operation_nature: payload["operationNature"],
        serie: payload["serie"],
        number: payload["number"],
        issued_on: payload["issuedOn"],
        operation_on: payload["operationOn"],
        issuer: Issuer.from_api(payload["issuer"]),
        buyer: Buyer.from_api(payload["buyer"]),
        totals: Totals.from_api(payload["totals"]),
        items: payload["items"] || []
      )
    end
  end
end
