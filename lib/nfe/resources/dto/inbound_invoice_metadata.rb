# frozen_string_literal: true

module Nfe
  # Immutable value object for the metadata of an inbound document (CT-e or
  # supplier NF-e) returned by the +api.nfse.io+ inbound endpoints when looked
  # up by 44-digit access key, or by an event lookup.
  #
  # Hand-written so the public surface stays small and snake_case. {from_api}
  # maps the API camelCase keys onto snake_case members, drops unknown keys, and
  # is nil-tolerant. The full payload is preserved in +details+ (including the
  # webhook-v2 +productInvoices+ array, when present) so callers can read fields
  # the SDK does not surface yet.
  class InboundInvoiceMetadata < Data.define(
    :access_key,
    :nsu,
    :status,
    :name_sender,
    :federal_tax_number_sender,
    :total_invoice_amount,
    :issued_on,
    :product_invoices,
    :details
  )
    # Build a {Nfe::InboundInvoiceMetadata} from an API payload.
    #
    # @param payload [Hash, nil] the inbound document metadata object.
    # @return [Nfe::InboundInvoiceMetadata, nil] +nil+ when +payload+ is +nil+.
    def self.from_api(payload)
      return nil if payload.nil?

      new(
        access_key: payload["accessKey"] || payload["accesskey"],
        nsu: payload["nsu"],
        status: payload["status"],
        name_sender: payload["nameSender"],
        federal_tax_number_sender: stringify(payload["federalTaxNumberSender"]),
        total_invoice_amount: payload["totalInvoiceAmount"],
        issued_on: payload["issuedOn"],
        product_invoices: payload["productInvoices"],
        details: payload
      )
    end

    # Coerce a tax number to a +String+ without numeric coercion. +nil+ stays
    # +nil+.
    #
    # @api private
    def self.stringify(value)
      value&.to_s
    end
  end
end
