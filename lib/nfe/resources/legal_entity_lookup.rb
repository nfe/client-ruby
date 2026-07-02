# frozen_string_literal: true

require "nfe/resources/abstract_resource"
require "nfe/resources/dto/legal_entity_lookup/legal_entity_responses"

module Nfe
  module Resources
    # Legal-entity (pessoa jurídica) lookup against the +:legal_entity+ data
    # family (+legalentity.api.nfe.io+). The version segment is embedded in
    # each request path (+/v2/legalentities/...+), so {#api_version} is +""+.
    class LegalEntityLookup < AbstractResource
      # Retrieve basic registration info for a CNPJ.
      #
      # @param federal_tax_number [String] CNPJ in any format.
      # @param update_address [Boolean, nil] forwarded as +updateAddress+ when set.
      # @param update_city_code [Boolean, nil] forwarded as +updateCityCode+ when set.
      # @return [Nfe::LegalEntityBasicInfoResponse]
      # @raise [Nfe::InvalidRequestError] when the CNPJ is not 14 characters.
      def get_basic_info(federal_tax_number, update_address: nil, update_city_code: nil)
        cnpj = Nfe::IdValidator.cnpj(federal_tax_number)
        query = { "updateAddress" => update_address, "updateCityCode" => update_city_code }.compact
        response = get("/v2/legalentities/basicInfo/#{cnpj}", query: query)
        hydrate(Nfe::LegalEntityBasicInfoResponse, parse_json(response.body))
      end

      # Retrieve state-tax registration info for a state + CNPJ.
      #
      # @param state [String] UF (case-insensitive).
      # @param federal_tax_number [String] CNPJ in any format.
      # @return [Nfe::LegalEntityStateTaxResponse]
      # @raise [Nfe::InvalidRequestError] on an invalid UF or CNPJ.
      def get_state_tax_info(state, federal_tax_number)
        uf = Nfe::IdValidator.state(state)
        cnpj = Nfe::IdValidator.cnpj(federal_tax_number)
        response = get("/v2/legalentities/stateTaxInfo/#{uf}/#{cnpj}")
        hydrate(Nfe::LegalEntityStateTaxResponse, parse_json(response.body))
      end

      # Retrieve the state-tax info suitable for invoicing.
      #
      # @param state [String] UF (case-insensitive).
      # @param federal_tax_number [String] CNPJ in any format.
      # @return [Nfe::LegalEntityStateTaxForInvoiceResponse]
      # @raise [Nfe::InvalidRequestError] on an invalid UF or CNPJ.
      def get_state_tax_for_invoice(state, federal_tax_number)
        uf = Nfe::IdValidator.state(state)
        cnpj = Nfe::IdValidator.cnpj(federal_tax_number)
        response = get("/v2/legalentities/stateTaxForInvoice/#{uf}/#{cnpj}")
        hydrate(Nfe::LegalEntityStateTaxForInvoiceResponse, parse_json(response.body))
      end

      # Retrieve the suggested state-tax info for invoicing.
      #
      # @param state [String] UF (case-insensitive).
      # @param federal_tax_number [String] CNPJ in any format.
      # @return [Nfe::LegalEntityStateTaxForInvoiceResponse]
      # @raise [Nfe::InvalidRequestError] on an invalid UF or CNPJ.
      def get_suggested_state_tax_for_invoice(state, federal_tax_number)
        uf = Nfe::IdValidator.state(state)
        cnpj = Nfe::IdValidator.cnpj(federal_tax_number)
        response = get("/v2/legalentities/stateTaxSuggestedForInvoice/#{uf}/#{cnpj}")
        hydrate(Nfe::LegalEntityStateTaxForInvoiceResponse, parse_json(response.body))
      end

      protected

      def api_family
        :legal_entity
      end

      # The version segment is embedded in each request path, so no version
      # prefix is added by {#full_path}.
      def api_version
        ""
      end
    end
  end
end
