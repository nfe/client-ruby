# frozen_string_literal: true

module Nfe
  module Resources
    # Result of an asynchronous (HTTP 202) service-invoice (NFS-e) emission: the
    # API accepted the request and is processing it. The document is not yet
    # materialized.
    #
    # +invoice_id+ is parsed from the +Location+ header's final path segment;
    # +location+ is the raw header value. Discriminate against
    # {Nfe::Resources::ServiceInvoiceIssued} with +pending?+/+issued?+ or +case+
    # pattern matching, then poll {Nfe::FlowStatus.terminal?} until settled.
    class ServiceInvoicePending < Data.define(:invoice_id, :location)
      # @return [true] this is an async (pending) result.
      def pending?
        true
      end

      # @return [false] this is not an immediate (issued) result.
      def issued?
        false
      end
    end
  end
end
