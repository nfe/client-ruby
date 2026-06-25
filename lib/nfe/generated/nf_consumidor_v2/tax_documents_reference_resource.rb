# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/nf-consumidor-v2.yaml
# Hash: sha256:8c39e692ff794ccb2587ebe142be040e44d76cbf970f45e65b28d56a6165bdb5

module Nfe
  module Generated
    module NfConsumidorV2
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
