# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/nf-consumidor-v2.yaml
# Hash: sha256:8c39e692ff794ccb2587ebe142be040e44d76cbf970f45e65b28d56a6165bdb5

module Nfe
  module Generated
    module NfConsumidorV2
      InvoiceItemResource = Data.define(:additional_information, :benefit, :cest, :cfop, :code, :code_gtin, :code_tax_gtin, :description, :discount_amount, :export_details, :extipi, :freight_amount, :fuel_detail, :ibs_zfm_presumed_credit_classification, :import_control_sheet_number, :import_declarations, :insurance_amount, :item_amount, :item_number_order_buy, :ncm, :number_order_buy, :nve, :others_amount, :presumed_credit, :quantity, :quantity_tax, :referenced_dfe, :tax, :tax_determination, :tax_unit_amount, :total_amount, :total_indicator, :unit, :unit_amount, :unit_tax, :used_movable_asset_indicator, :vehicle_detail) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            additional_information: payload["additionalInformation"],
            benefit: payload["benefit"],
            cest: payload["cest"],
            cfop: payload["cfop"],
            code: payload["code"],
            code_gtin: payload["codeGTIN"],
            code_tax_gtin: payload["codeTaxGTIN"],
            description: payload["description"],
            discount_amount: payload["discountAmount"],
            export_details: (payload["exportDetails"] || []).map { |e| ExportDetailResource.from_api(e) },
            extipi: payload["extipi"],
            freight_amount: payload["freightAmount"],
            fuel_detail: FuelResource.from_api(payload["fuelDetail"]),
            ibs_zfm_presumed_credit_classification: payload["ibsZfmPresumedCreditClassification"],
            import_control_sheet_number: payload["importControlSheetNumber"],
            import_declarations: (payload["importDeclarations"] || []).map { |e| ImportDeclarationResource.from_api(e) },
            insurance_amount: payload["insuranceAmount"],
            item_amount: payload["itemAmount"],
            item_number_order_buy: payload["itemNumberOrderBuy"],
            ncm: payload["ncm"],
            number_order_buy: payload["numberOrderBuy"],
            nve: payload["nve"],
            others_amount: payload["othersAmount"],
            presumed_credit: PresumedCreditResource.from_api(payload["presumedCredit"]),
            quantity: payload["quantity"],
            quantity_tax: payload["quantityTax"],
            referenced_dfe: ReferencedDFeResource.from_api(payload["referencedDFe"]),
            tax: InvoiceItemTaxResource.from_api(payload["tax"]),
            tax_determination: TaxDeterminationResource.from_api(payload["taxDetermination"]),
            tax_unit_amount: payload["taxUnitAmount"],
            total_amount: payload["totalAmount"],
            total_indicator: payload["totalIndicator"],
            unit: payload["unit"],
            unit_amount: payload["unitAmount"],
            unit_tax: payload["unitTax"],
            used_movable_asset_indicator: payload["usedMovableAssetIndicator"],
            vehicle_detail: VehicleDetailResource.from_api(payload["vehicleDetail"]),
          )
        end
      end
    end
  end
end
