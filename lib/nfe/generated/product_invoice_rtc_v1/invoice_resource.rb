# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/product-invoice-rtc-v1.yaml
# Hash: sha256:4327ad141eeace6219dc4267678c44a134ae1fdde93f7dd69cf4c9ae9418415a

module Nfe
  module Generated
    module ProductInvoiceRtcV1
      InvoiceResource = Data.define(:additional_information, :authorization, :billing, :buyer, :contingency_details, :created_on, :delivery, :environment_type, :export, :id, :issuer, :last_events, :modified_on, :number, :operation_nature, :operation_on, :operation_type, :payment, :purpose_type, :serie, :status, :totals, :transaction_intermediate, :transport, :withdrawal) do
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
            last_events: InvoiceEventsResourceBase.from_api(payload["lastEvents"]),
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
