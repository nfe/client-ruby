# frozen_string_literal: true

module Nfe
  module Resources
    # Result of an asynchronous (HTTP 202) RTC service-invoice (NFS-e) emission:
    # the API accepted the request and is processing it. The document is not yet
    # materialized.
    #
    # +invoice_id+ is parsed from the +Location+ header's final path segment;
    # +location+ is the raw header value. Discriminate against
    # {Nfe::Resources::ServiceInvoiceRtcIssued} with +pending?+/+issued?+ or
    # +case+ pattern matching, then poll until the document settles.
    #
    # RTC and classic NFS-e share the same endpoint; the RTC layout is selected
    # by the presence of the +ibsCbs+ group in the create payload, so the async
    # 202 shape is identical to the classic flow.
    class ServiceInvoiceRtcPending < Data.define(:invoice_id, :location)
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
