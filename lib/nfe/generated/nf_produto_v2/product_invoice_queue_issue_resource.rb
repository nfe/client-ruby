# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/nf-produto-v2.yaml
# Hash: sha256:e565b47e4d8b17255f99efc2b6354d589d2903c4ba9b97caabd74f84de59e4e2

module Nfe
  module Generated
    module NfProdutoV2
      ProductInvoiceQueueIssueResource = Data.define(:additional_information, :billing, :buyer, :consumer_type, :contingency_justification, :contingency_on, :delivery, :destination, :export, :id, :issuer, :items, :number, :operation_nature, :operation_on, :operation_type, :payment, :presence_type, :print_type, :purpose_type, :serie, :totals, :transaction_intermediate, :transport, :withdrawal) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            additional_information: AdditionalInformationResource.from_api(payload["additionalInformation"]),
            billing: BillingResource.from_api(payload["billing"]),
            buyer: BuyerResource.from_api(payload["buyer"]),
            consumer_type: payload["consumerType"],
            contingency_justification: payload["contingencyJustification"],
            contingency_on: payload["contingencyOn"],
            delivery: DeliveryInformationResource.from_api(payload["delivery"]),
            destination: payload["destination"],
            export: ExportResource.from_api(payload["export"]),
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
