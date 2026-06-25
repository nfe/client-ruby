# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/nf-consumidor-v2.yaml
# Hash: sha256:8c39e692ff794ccb2587ebe142be040e44d76cbf970f45e65b28d56a6165bdb5

module Nfe
  module Generated
    module NfConsumidorV2
      IBSCBSTotalsResource = Data.define(:basis, :cbs, :credit_reversal, :ibs, :monophase) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            basis: payload["basis"],
            cbs: CBSTotalsResource.from_api(payload["cbs"]),
            credit_reversal: CreditReversalTotalsResource.from_api(payload["creditReversal"]),
            ibs: IBSTotalsResource.from_api(payload["ibs"]),
            monophase: MonophaseTotalsResource.from_api(payload["monophase"]),
          )
        end
      end
    end
  end
end
