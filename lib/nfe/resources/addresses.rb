# frozen_string_literal: true

require "nfe/resources/abstract_resource"

module Nfe
  module Resources
    # Resource stub for the +:addresses+ family. Business methods are filled in by
    # the +add-lookup-resources+ change; calling one before then raises +NotImplementedError+
    # naming that change.
    class Addresses < AbstractResource
      # The change that implements this resource's business methods.
      IMPLEMENTED_IN = "add-lookup-resources"

      protected

      def api_family
        :addresses
      end

      # This family's host already embeds the API version, so no version
      # segment is prefixed to the request path.
      def api_version
        ""
      end

      private

      # Business methods are not implemented in this change. Calling one
      # raises +NotImplementedError+ naming the change that fills it.
      def method_missing(name, *_args, **_kwargs)
        raise NotImplementedError,
              "Nfe::Resources::Addresses##{name} is not implemented yet; " \
              "it is implemented in the #{IMPLEMENTED_IN} change."
      end

      def respond_to_missing?(_name, _include_private = false)
        false
      end
    end
  end
end
