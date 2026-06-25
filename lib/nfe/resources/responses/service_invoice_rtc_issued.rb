# frozen_string_literal: true

module Nfe
  module Resources
    # Result of an immediate (HTTP 201/200) RTC service-invoice (NFS-e) emission:
    # the document was materialized synchronously. +resource+ is the hydrated
    # {Nfe::ServiceInvoice} value object — the RTC create endpoint returns the
    # standard NFS-e body shape, so the classic hand-written DTO is reused (the
    # generated +ServiceInvoiceRtcV1::NFSeRequest+ describes only the request).
    #
    # Discriminate against {Nfe::Resources::ServiceInvoiceRtcPending} with
    # +pending?+/+issued?+ or +case+ pattern matching.
    class ServiceInvoiceRtcIssued < Data.define(:resource)
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
