# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/nf-consumidor-v2.yaml
# Hash: sha256:8c39e692ff794ccb2587ebe142be040e44d76cbf970f45e65b28d56a6165bdb5

module Nfe
  module Generated
    module NfConsumidorV2
      OperationalPresumedCreditResource = Data.define(:basis, :cbs, :classification_code, :ibs) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            basis: payload["basis"],
            cbs: PresumedCreditDetailsResource.from_api(payload["cbs"]),
            classification_code: payload["classificationCode"],
            ibs: PresumedCreditDetailsResource.from_api(payload["ibs"]),
          )
        end
      end
    end
  end
end
