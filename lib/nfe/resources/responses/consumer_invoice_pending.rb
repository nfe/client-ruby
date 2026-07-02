# frozen_string_literal: true

module Nfe
  module Resources
    # Discriminated result of an asynchronous NFC-e emission (HTTP 202): the
    # API accepted the request and is processing it; the document is not yet
    # materialized. +invoice_id+ is parsed from the +Location+ header's final
    # path segment and +location+ is the raw header value.
    #
    # Discriminate against {Nfe::Resources::ConsumerInvoiceIssued} with the
    # +pending?+/+issued?+ predicates or +case+/+in+ pattern matching, then poll
    # {Nfe::FlowStatus.terminal?} until the invoice settles.
    #
    # @example
    #   result = client.consumer_invoices.create(company_id: id, data: payload)
    #   result.pending? # => true
    #   result.invoice_id
    class ConsumerInvoicePending < Data.define(:invoice_id, :location)
      # @return [Boolean] always +true+ for a pending result.
      def pending?
        true
      end

      # @return [Boolean] always +false+ for a pending result.
      def issued?
        false
      end
    end
  end
end
