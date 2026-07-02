# frozen_string_literal: true

module Nfe
  module Resources
    # Discriminated result of a synchronous NFC-e emission (HTTP 201/200): the
    # document was materialized immediately. +resource+ is the hydrated
    # {Nfe::ConsumerInvoice} value object.
    #
    # Discriminate against {Nfe::Resources::ConsumerInvoicePending} with the
    # +pending?+/+issued?+ predicates or +case+/+in+ pattern matching.
    #
    # @example
    #   result = client.consumer_invoices.create(company_id: id, data: payload)
    #   result.resource if result.issued?
    class ConsumerInvoiceIssued < Data.define(:resource)
      # @return [Boolean] always +false+ for an issued result.
      def pending?
        false
      end

      # @return [Boolean] always +true+ for an issued result.
      def issued?
        true
      end
    end
  end
end
