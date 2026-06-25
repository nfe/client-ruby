# frozen_string_literal: true

module Nfe
  module Resources
    # Result of an immediate (HTTP 201/200) product-invoice (NF-e) emission: the
    # document was materialized synchronously. +resource+ is the hydrated
    # {Nfe::ProductInvoice} value object.
    #
    # Discriminate against {Nfe::Resources::ProductInvoicePending} with
    # +pending?+/+issued?+ or +case+ pattern matching.
    class ProductInvoiceIssued < Data.define(:resource)
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
