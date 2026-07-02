# frozen_string_literal: true

module Nfe
  module Resources
    # Result of an asynchronous (HTTP 202) product-invoice (NF-e) emission: the
    # API enqueued the request and is processing it. Completion is notified via
    # webhook.
    #
    # +invoice_id+ is parsed from the +Location+ header's final path segment;
    # +location+ is the raw header value. Discriminate against
    # {Nfe::Resources::ProductInvoiceIssued} with +pending?+/+issued?+ or +case+
    # pattern matching, then poll {Nfe::FlowStatus.terminal?} until settled.
    class ProductInvoicePending < Data.define(:invoice_id, :location)
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
