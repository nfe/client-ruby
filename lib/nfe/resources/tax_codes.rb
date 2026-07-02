# frozen_string_literal: true

require "nfe/resources/abstract_resource"
require "nfe/resources/dto/tax_codes/tax_code_paginated_response"

module Nfe
  module Resources
    # CT-e tax-code lookup tables for the +:cte+ host family
    # (+https://api.nfse.io/tax-codes/...+). Exposes the four reference lists
    # consumed when building a CT-e: operation codes, acquisition purposes, and
    # the issuer/recipient tax profiles.
    #
    # These endpoints paginate page-style (1-based +pageIndex+/+pageCount+), so
    # every method returns an {Nfe::TaxCodePaginatedResponse} (NOT an
    # {Nfe::ListResponse}); see that class for why this differs from the
    # cursor-style lists elsewhere in the SDK.
    #
    # @example
    #   client.tax_codes.list_operation_codes(page_index: 2, page_count: 20)
    class TaxCodes < AbstractResource
      protected

      def api_family
        :cte
      end

      # The +:cte+ host (+api.nfse.io+) does not bake in a version and these
      # tax-code paths carry none, so no version segment is prefixed.
      def api_version
        ""
      end

      public

      # List CT-e operation codes (Código de Operação).
      #
      # @param page_index [Integer, nil] 1-based page index (preserved as given).
      # @param page_count [Integer, nil] page size.
      # @return [Nfe::TaxCodePaginatedResponse]
      def list_operation_codes(page_index: nil, page_count: nil)
        list_tax_codes("/tax-codes/operation-code", page_index, page_count)
      end

      # List CT-e acquisition purposes (Finalidade de Aquisição).
      #
      # @param page_index [Integer, nil] 1-based page index (preserved as given).
      # @param page_count [Integer, nil] page size.
      # @return [Nfe::TaxCodePaginatedResponse]
      def list_acquisition_purposes(page_index: nil, page_count: nil)
        list_tax_codes("/tax-codes/acquisition-purpose", page_index, page_count)
      end

      # List CT-e issuer tax profiles (Perfil Tributário do Emitente).
      #
      # @param page_index [Integer, nil] 1-based page index (preserved as given).
      # @param page_count [Integer, nil] page size.
      # @return [Nfe::TaxCodePaginatedResponse]
      def list_issuer_tax_profiles(page_index: nil, page_count: nil)
        list_tax_codes("/tax-codes/issuer-tax-profile", page_index, page_count)
      end

      # List CT-e recipient tax profiles (Perfil Tributário do Destinatário).
      #
      # @param page_index [Integer, nil] 1-based page index (preserved as given).
      # @param page_count [Integer, nil] page size.
      # @return [Nfe::TaxCodePaginatedResponse]
      def list_recipient_tax_profiles(page_index: nil, page_count: nil)
        list_tax_codes("/tax-codes/recipient-tax-profile", page_index, page_count)
      end

      private

      # Shared GET + page-style query builder for the four tax-code endpoints.
      # Only the non-nil paging parameters are sent, keeping them out of the URL
      # when omitted.
      def list_tax_codes(path, page_index, page_count)
        query = {} #: Hash[String, untyped]
        query["pageIndex"] = page_index unless page_index.nil?
        query["pageCount"] = page_count unless page_count.nil?
        response = get(path, query: query)
        hydrate(Nfe::TaxCodePaginatedResponse, parse_json(response.body))
      end
    end
  end
end
