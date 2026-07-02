# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/nf-produto-v2.yaml
# Hash: sha256:e565b47e4d8b17255f99efc2b6354d589d2903c4ba9b97caabd74f84de59e4e2

module Nfe
  module Generated
    module NfProdutoV2
      AdditionalInformationResource = Data.define(:contract, :effort, :fisco, :order, :referenced_process, :tax_documents_reference, :taxpayer, :taxpayer_comments, :xml_authorized) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
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
