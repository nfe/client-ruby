# frozen_string_literal: true

require "nfe/resources/dto/legal_entity_lookup/state_tax_legal_entity"

module Nfe
  # Immutable value object for a legal entity (pessoa jurídica) as returned by
  # the NFE.io +legalentity.api.nfe.io+ +basicInfo+ lookup. All fields are
  # optional; {from_api} maps API camelCase keys onto snake_case members and is
  # nil-tolerant (+from_api(nil)+ returns +nil+).
  #
  # +federal_tax_number+ is kept as a +String+ (CNPJ), never coerced to
  # Integer, preserving future alphanumeric CNPJ. +address+, +phones+,
  # +partners+ and +economic_activities+ are passed through opaquely.
  class LegalEntity < Data.define(
    :federal_tax_number,
    :name,
    :trade_name,
    :status,
    :status_on,
    :status_reason,
    :legal_nature,
    :size,
    :opened_on,
    :issued_on,
    :special_status,
    :special_status_on,
    :responsable_entity,
    :share_capital,
    :registration_unit,
    :unit,
    :address,
    :phones,
    :email,
    :economic_activities,
    :partners
  )
    # @param payload [Hash, nil] the unwrapped legal-entity object.
    # @return [Nfe::LegalEntity, nil] +nil+ when +payload+ is +nil+.
    def self.from_api(payload)
      return nil if payload.nil?

      new(
        federal_tax_number: payload["federalTaxNumber"]&.to_s,
        name: payload["name"],
        trade_name: payload["tradeName"],
        status: payload["status"],
        status_on: payload["statusOn"],
        status_reason: payload["statusReason"],
        legal_nature: payload["legalNature"],
        size: payload["size"],
        opened_on: payload["openedOn"],
        issued_on: payload["issuedOn"],
        special_status: payload["specialStatus"],
        special_status_on: payload["specialStatusOn"],
        responsable_entity: payload["responsableEntity"],
        share_capital: payload["shareCapital"],
        registration_unit: payload["registrationUnit"],
        unit: payload["unit"],
        address: payload["address"],
        phones: payload["phones"],
        email: payload["email"],
        economic_activities: payload["economicActivities"],
        partners: payload["partners"]
      )
    end
  end

  # Immutable wrapper for a +basicInfo+ lookup response.
  class LegalEntityBasicInfoResponse < Data.define(:legal_entity)
    # @param payload [Hash, nil] the parsed response body.
    # @return [Nfe::LegalEntityBasicInfoResponse, nil] +nil+ when +payload+ is +nil+.
    def self.from_api(payload)
      return nil if payload.nil?

      new(
        legal_entity: Nfe::LegalEntity.from_api(payload["legalEntity"] || payload)
      )
    end
  end

  # Immutable wrapper for a +stateTaxInfo+ lookup response. The body wraps a
  # +legalEntity+ object with the state-tax shape ({Nfe::StateTaxLegalEntity});
  # all state-tax data lives there (inside +stateTaxes+), not at the top level.
  class LegalEntityStateTaxResponse < Data.define(:legal_entity)
    # @param payload [Hash, nil] the parsed response body.
    # @return [Nfe::LegalEntityStateTaxResponse, nil] +nil+ when +payload+ is +nil+.
    def self.from_api(payload)
      return nil if payload.nil?

      new(
        legal_entity: Nfe::StateTaxLegalEntity.from_api(payload["legalEntity"] || payload)
      )
    end
  end

  # Immutable wrapper for a +stateTaxForInvoice+ / +stateTaxSuggestedForInvoice+
  # lookup response. Same +legalEntity+ state-tax shape as
  # {Nfe::LegalEntityStateTaxResponse}; the per-IE status enum is extended for
  # invoice evaluation but the structure is identical.
  class LegalEntityStateTaxForInvoiceResponse < Data.define(:legal_entity)
    # @param payload [Hash, nil] the parsed response body.
    # @return [Nfe::LegalEntityStateTaxForInvoiceResponse, nil] +nil+ when +payload+ is +nil+.
    def self.from_api(payload)
      return nil if payload.nil?

      new(
        legal_entity: Nfe::StateTaxLegalEntity.from_api(payload["legalEntity"] || payload)
      )
    end
  end
end
