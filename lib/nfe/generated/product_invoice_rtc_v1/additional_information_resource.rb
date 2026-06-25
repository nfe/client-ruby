# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/product-invoice-rtc-v1.yaml
# Hash: sha256:4327ad141eeace6219dc4267678c44a134ae1fdde93f7dd69cf4c9ae9418415a

module Nfe
  module Generated
    module ProductInvoiceRtcV1
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
