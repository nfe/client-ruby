# frozen_string_literal: true

module Nfe
  # A single CT-e tax-code entry (operation code, acquisition purpose, issuer or
  # recipient tax profile). Hand-written: the +consulta-cte+ tax-code endpoints
  # are schema-less in the OpenAPI spec, so the generator produces no usable
  # model. {from_api} maps the API camelCase keys onto snake_case members and is
  # nil-tolerant (+from_api(nil)+ returns +nil+).
  class TaxCode < Data.define(:code, :description)
    # Build a {Nfe::TaxCode} from an API payload.
    #
    # @param payload [Hash, nil] the response object.
    # @return [Nfe::TaxCode, nil] +nil+ when +payload+ is +nil+.
    def self.from_api(payload)
      return nil if payload.nil?

      new(
        code: payload["code"],
        description: payload["description"]
      )
    end
  end

  # Page-style paginated response for the CT-e tax-code lookup endpoints
  # (operation code, acquisition purpose, issuer/recipient tax profile).
  #
  # NOTE: unlike the cursor-style lists elsewhere in this SDK (which return an
  # {Nfe::ListResponse} carrying +starting_after+/+ending_before+), these tax-code
  # endpoints are 1-based page-style, so this resource returns this custom
  # response object exposing +current_page+/+total_pages+/+total_count+ directly.
  #
  # +items+ is hydrated to an Array of {Nfe::TaxCode}. {from_api} is nil-tolerant
  # (+from_api(nil)+ returns +nil+).
  class TaxCodePaginatedResponse < Data.define(:current_page, :total_pages, :total_count, :items)
    # Build a {Nfe::TaxCodePaginatedResponse} from an API payload.
    #
    # @param payload [Hash, nil] the response object.
    # @return [Nfe::TaxCodePaginatedResponse, nil] +nil+ when +payload+ is +nil+.
    def self.from_api(payload)
      return nil if payload.nil?

      new(
        current_page: payload["currentPage"],
        total_pages: payload["totalPages"],
        total_count: payload["totalCount"],
        items: (payload["items"] || []).map { |item| Nfe::TaxCode.from_api(item) }
      )
    end
  end
end
