# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/nf-consumidor-v2.yaml
# Hash: sha256:8c39e692ff794ccb2587ebe142be040e44d76cbf970f45e65b28d56a6165bdb5

module Nfe
  module Generated
    module NfConsumidorV2
      ConsumerInvoiceRequest = Data.define(:additional_information, :billing, :buyer, :consumer_type, :consumption_city_code, :contingency_justification, :contingency_on, :credit_type, :debit_type, :destination, :government_purchase, :ibs_consumption_city_code, :id, :issuer, :items, :number, :operation_nature, :operation_on, :operation_type, :payment, :presence_type, :print_type, :purpose_type, :serie, :totals, :transaction_intermediate, :transport) do
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
            destination: payload["destination"],
            government_purchase: GovernmentPurchaseResource.from_api(payload["governmentPurchase"]),
            ibs_consumption_city_code: payload["ibsConsumptionCityCode"],
            id: payload["id"],
            issuer: IssuerFromRequestResource.from_api(payload["issuer"]),
            items: (payload["items"] || []).map { |e| InvoiceItemResource.from_api(e) },
            number: payload["number"],
            operation_nature: payload["operationNature"],
            operation_on: payload["operationOn"],
            operation_type: payload["operationType"],
            payment: (payload["payment"] || []).map { |e| PaymentResource.from_api(e) },
            presence_type: payload["presenceType"],
            print_type: payload["printType"],
            purpose_type: payload["purposeType"],
            serie: payload["serie"],
            totals: TotalResource.from_api(payload["totals"]),
            transaction_intermediate: IntermediateResource.from_api(payload["transactionIntermediate"]),
            transport: TransportInformationResource.from_api(payload["transport"]),
          )
        end
      end
    end
  end
end
