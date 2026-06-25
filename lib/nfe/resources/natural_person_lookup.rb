# frozen_string_literal: true

require "nfe/resources/abstract_resource"

module Nfe
  module Resources
    # Resource stub for the +:natural_person+ family. Business methods are filled in by
    # the +add-lookup-resources+ change; calling one before then raises +NotImplementedError+
    # naming that change.
    class NaturalPersonLookup < AbstractResource
      # The change that implements this resource's business methods.
      IMPLEMENTED_IN = "add-lookup-resources"

      protected

      def api_family
        :natural_person
      end

      private

      # Business methods are not implemented in this change. Calling one
      # raises +NotImplementedError+ naming the change that fills it.
      def method_missing(name, *_args, **_kwargs)
        raise NotImplementedError,
              "Nfe::Resources::NaturalPersonLookup##{name} is not implemented yet; " \
              "it is implemented in the #{IMPLEMENTED_IN} change."
      end

      def respond_to_missing?(_name, _include_private = false)
        false
      end
    end
  end
end
