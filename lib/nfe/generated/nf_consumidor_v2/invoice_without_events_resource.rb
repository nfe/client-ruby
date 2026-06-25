# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/nf-consumidor-v2.yaml
# Hash: sha256:8c39e692ff794ccb2587ebe142be040e44d76cbf970f45e65b28d56a6165bdb5

module Nfe
  module Generated
    module NfConsumidorV2
      InvoiceWithoutEventsResource = Data.define(:additional_information, :authorization, :billing, :buyer, :contingency_details, :created_on, :delivery, :environment_type, :export, :id, :issuer, :modified_on, :number, :operation_nature, :operation_on, :operation_type, :payment, :purpose_type, :serie, :status, :totals, :transaction_intermediate, :transport, :withdrawal) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            additional_information: AdditionalInformationResource.from_api(payload["additionalInformation"]),
            authorization: AuthorizationResource.from_api(payload["authorization"]),
            billing: BillingResource.from_api(payload["billing"]),
            buyer: BuyerResource.from_api(payload["buyer"]),
            contingency_details: ContingencyDetails.from_api(payload["contingencyDetails"]),
            created_on: payload["createdOn"],
            delivery: DeliveryInformationResource.from_api(payload["delivery"]),
            environment_type: payload["environmentType"],
            export: ExportResource.from_api(payload["export"]),
            id: payload["id"],
            issuer: IssuerResource.from_api(payload["issuer"]),
            modified_on: payload["modifiedOn"],
            number: payload["number"],
            operation_nature: payload["operationNature"],
            operation_on: payload["operationOn"],
            operation_type: payload["operationType"],
            payment: (payload["payment"] || []).map { |e| PaymentResource.from_api(e) },
            purpose_type: payload["purposeType"],
            serie: payload["serie"],
            status: payload["status"],
            totals: TotalResource.from_api(payload["totals"]),
            transaction_intermediate: IntermediateResource.from_api(payload["transactionIntermediate"]),
            transport: TransportInformationResource.from_api(payload["transport"]),
            withdrawal: WithdrawalInformationResource.from_api(payload["withdrawal"]),
          )
        end
      end
    end
  end
end
