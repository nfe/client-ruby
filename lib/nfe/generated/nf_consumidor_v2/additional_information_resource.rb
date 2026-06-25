# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/nf-consumidor-v2.yaml
# Hash: sha256:8c39e692ff794ccb2587ebe142be040e44d76cbf970f45e65b28d56a6165bdb5

module Nfe
  module Generated
    module NfConsumidorV2
      AdditionalInformationResource = Data.define(:advance_payment, :contract, :effort, :fisco, :order, :referenced_process, :tax_documents_reference, :taxpayer, :taxpayer_comments, :xml_authorized) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            advance_payment: (payload["advancePayment"] || []).map { |e| AdvancePaymentItemResource.from_api(e) },
            contract: payload["contract"],
            effort: payload["effort"],
            fisco: payload["fisco"],
            order: payload["order"],
            referenced_process: (payload["referencedProcess"] || []).map { |e| ReferencedProcessResource.from_api(e) },
            tax_documents_reference: (payload["taxDocumentsReference"] || []).map { |e| TaxDocumentsReferenceResource.from_api(e) },
            taxpayer: payload["taxpayer"],
            taxpayer_comments: (payload["taxpayerComments"] || []).map { |e| TaxpayerCommentsResource.from_api(e) },
            xml_authorized: payload["xmlAuthorized"],
          )
        end
      end
    end
  end
end
