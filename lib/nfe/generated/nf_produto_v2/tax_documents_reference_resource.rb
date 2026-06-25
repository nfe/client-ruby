# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/nf-produto-v2.yaml
# Hash: sha256:e565b47e4d8b17255f99efc2b6354d589d2903c4ba9b97caabd74f84de59e4e2

module Nfe
  module Generated
    module NfProdutoV2
      TaxDocumentsReferenceResource = Data.define(:document_electronic_invoice, :document_invoice_reference, :tax_coupon_information) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            document_electronic_invoice: DocumentElectronicInvoiceResource.from_api(payload["documentElectronicInvoice"]),
            document_invoice_reference: DocumentInvoiceReferenceResource.from_api(payload["documentInvoiceReference"]),
            tax_coupon_information: TaxCouponInformationResource.from_api(payload["taxCouponInformation"]),
          )
        end
      end
    end
  end
end
