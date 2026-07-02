# frozen_string_literal: true

module Nfe
  module Resources
    # Result of an immediate (HTTP 201/200) RTC product-invoice (NF-e/NFC-e under
    # the Reforma Tributária layout) emission: the document was materialized
    # synchronously. +resource+ is the hydrated
    # {Nfe::Generated::ProductInvoiceRtcV1::InvoiceResource} value object.
    #
    # Discriminate against {Nfe::Resources::ProductInvoiceRtcPending} with
    # +pending?+/+issued?+ or +case+ pattern matching.
    class ProductInvoiceRtcIssued < Data.define(:resource)
      # @return [false] this is not an async (pending) result.
      def pending?
        false
      end

      # @return [true] this is an immediate (issued) result.
      def issued?
        true
      end
    end
  end
end
