# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/product-invoice-rtc-v1.yaml
# Hash: sha256:4327ad141eeace6219dc4267678c44a134ae1fdde93f7dd69cf4c9ae9418415a

module Nfe
  module Generated
    module ProductInvoiceRtcV1
      ProductInvoiceRequest = Data.define(:additional_information, :billing, :buyer, :consumer_type, :consumption_city_code, :contingency_justification, :contingency_on, :credit_type, :debit_type, :delivery, :destination, :expected_delivery_on, :export, :government_purchase, :ibs_consumption_city_code, :id, :issuer_tax_substitute, :items, :number, :operation_nature, :operation_on, :operation_type, :payment, :presence_type, :print_type, :purchase_information, :purpose_type, :serie, :totals, :transaction_intermediate, :transport, :withdrawal) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            additional_information: AdditionalInformationResource.from_api(payload["additionalInformation"]),
            billing: BillingResource.from_api(payload["billing"]),
            buyer: BuyerResource.from_api(payload["buyer"]),
            consumer_type: payload["consumerType"],
            consumption_city_code: payload["consumptionCityCode"],
            contingency_justification: payload["contingencyJustification"],
            contingency_on: payload["contingencyOn"],
            credit_type: payload["creditType"],
            debit_type: payload["debitType"],
            delivery: DeliveryInformationResource.from_api(payload["delivery"]),
            destination: payload["destination"],
            expected_delivery_on: payload["expectedDeliveryOn"],
            export: ExportResource.from_api(payload["export"]),
            government_purchase: GovernmentPurchaseResource.from_api(payload["governmentPurchase"]),
            ibs_consumption_city_code: payload["ibsConsumptionCityCode"],
            id: payload["id"],
            issuer_tax_substitute: IssuerFromRequestResource.from_api(payload["issuerTaxSubstitute"]),
            items: (payload["items"] || []).map { |e| InvoiceItemResource.from_api(e) },
            number: payload["number"],
            operation_nature: payload["operationNature"],
            operation_on: payload["operationOn"],
            operation_type: payload["operationType"],
            payment: (payload["payment"] || []).map { |e| PaymentResource.from_api(e) },
            presence_type: payload["presenceType"],
            print_type: payload["printType"],
            purchase_information: PurchaseInformationResource.from_api(payload["purchaseInformation"]),
            purpose_type: payload["purposeType"],
            serie: payload["serie"],
            totals: Total.from_api(payload["totals"]),
            transaction_intermediate: IntermediateResource.from_api(payload["transactionIntermediate"]),
            transport: TransportInformationResource.from_api(payload["transport"]),
            withdrawal: WithdrawalInformationResource.from_api(payload["withdrawal"]),
          )
        end
      end
    end
  end
end
