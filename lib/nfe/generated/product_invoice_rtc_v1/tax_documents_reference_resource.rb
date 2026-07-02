# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/product-invoice-rtc-v1.yaml
# Hash: sha256:4327ad141eeace6219dc4267678c44a134ae1fdde93f7dd69cf4c9ae9418415a

module Nfe
  module Generated
    module ProductInvoiceRtcV1
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
