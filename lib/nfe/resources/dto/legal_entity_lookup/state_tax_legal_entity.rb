# frozen_string_literal: true

module Nfe
  # Immutable value object for the +legalEntity+ object returned by the NFE.io
  # state-tax lookup endpoints (+stateTaxInfo+, +stateTaxForInvoice+,
  # +stateTaxSuggestedForInvoice+) on +legalentity.api.nfe.io+.
  #
  # This is a DIFFERENT shape from the +basicInfo+ {Nfe::LegalEntity}: it carries
  # the company-level tax-regime fields plus a +stateTaxes+ collection of state
  # registrations (Inscrições Estaduais). All fields are optional; {from_api}
  # maps API camelCase keys onto snake_case members and is nil-tolerant
  # (+from_api(nil)+ returns +nil+).
  class StateTaxLegalEntity < Data.define(
    :federal_tax_number,
    :name,
    :trade_name,
    :tax_regime,
    :legal_nature,
    :fiscal_unit,
    :created_unit,
    :created_on,
    :check_code,
    :state_taxes
  )
    # Address nested inside a state-tax registration. Pragmatic subset of the
    # address fields exposed by the state-tax endpoints.
    class Address < Data.define(:street, :number, :district, :postal_code, :city, :state, :country)
      def self.from_api(payload)
        return nil if payload.nil?

        new(
          street: payload["street"],
          number: payload["number"]&.to_s,
          district: payload["district"],
          postal_code: payload["postalCode"]&.to_s,
          city: payload["city"],
          state: payload["state"],
          country: payload["country"]
        )
      end
    end

    # Economic activity (CNAE) nested inside a state-tax registration.
    class EconomicActivity < Data.define(:type, :code, :description)
      def self.from_api(payload)
        return nil if payload.nil?

        new(
          type: payload["type"],
          code: payload["code"]&.to_s,
          description: payload["description"]
        )
      end
    end

    # Fiscal-document contributor indicator (NFe/NFSe/CTe/NFCe) inside a
    # state-tax registration.
    class FiscalDocumentInfo < Data.define(:status, :description)
      def self.from_api(payload)
        return nil if payload.nil?

        new(
          status: payload["status"],
          description: payload["description"]
        )
      end
    end

    # A single state-tax registration (Inscrição Estadual) within
    # +stateTaxes+. Carries its own status, dates, code, address and the
    # per-document contributor indicators.
    class StateTax < Data.define(
      :status,
      :tax_number,
      :status_on,
      :opened_on,
      :closed_on,
      :additional_information,
      :code,
      :address,
      :economic_activities,
      :nfe,
      :nfse,
      :cte,
      :nfce
    )
      def self.from_api(payload)
        return nil if payload.nil?

        new(
          status: payload["status"],
          tax_number: payload["taxNumber"]&.to_s,
          status_on: payload["statusOn"],
          opened_on: payload["openedOn"],
          closed_on: payload["closedOn"],
          additional_information: payload["additionalInformation"],
          code: payload["code"]&.to_s,
          address: Address.from_api(payload["address"]),
          economic_activities: (payload["economicActivities"] || []).map { |a| EconomicActivity.from_api(a) },
          nfe: FiscalDocumentInfo.from_api(payload["nfe"]),
          nfse: FiscalDocumentInfo.from_api(payload["nfse"]),
          cte: FiscalDocumentInfo.from_api(payload["cte"]),
          nfce: FiscalDocumentInfo.from_api(payload["nfce"])
        )
      end
    end

    # @param payload [Hash, nil] the unwrapped +legalEntity+ state-tax object.
    # @return [Nfe::StateTaxLegalEntity, nil] +nil+ when +payload+ is +nil+.
    def self.from_api(payload)
      return nil if payload.nil?

      new(
        federal_tax_number: payload["federalTaxNumber"]&.to_s,
        name: payload["name"],
        trade_name: payload["tradeName"],
        tax_regime: payload["taxRegime"],
        legal_nature: payload["legalNature"],
        fiscal_unit: payload["fiscalUnit"],
        created_unit: payload["createdUnit"],
        created_on: payload["createdOn"],
        check_code: payload["checkCode"]&.to_s,
        state_taxes: (payload["stateTaxes"] || []).map { |t| StateTax.from_api(t) }
      )
    end
  end
end
