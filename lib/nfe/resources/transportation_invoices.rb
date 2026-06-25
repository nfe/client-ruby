# frozen_string_literal: true

require "nfe/resources/abstract_resource"

module Nfe
  module Resources
    # Resource stub for the +:cte+ family. Business methods are filled in by
    # the +add-invoice-resources+ change; calling one before then raises +NotImplementedError+
    # naming that change.
    class TransportationInvoices < AbstractResource
      # The change that implements this resource's business methods.
      IMPLEMENTED_IN = "add-invoice-resources"

      protected

      def api_family
        :cte
      end

      private

      # Business methods are not implemented in this change. Calling one
      # raises +NotImplementedError+ naming the change that fills it.
      def method_missing(name, *_args, **_kwargs)
        raise NotImplementedError,
              "Nfe::Resources::TransportationInvoices##{name} is not implemented yet; " \
              "it is implemented in the #{IMPLEMENTED_IN} change."
      end

      def respond_to_missing?(_name, _include_private = false)
        false
      end
    end
  end
end
