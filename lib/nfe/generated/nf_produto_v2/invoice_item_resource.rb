# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/nf-produto-v2.yaml
# Hash: sha256:e565b47e4d8b17255f99efc2b6354d589d2903c4ba9b97caabd74f84de59e4e2

module Nfe
  module Generated
    module NfProdutoV2
      InvoiceItemResource = Data.define(:additional_information, :benefit, :cest, :cfop, :code, :code_gtin, :code_tax_gtin, :description, :discount_amount, :export_details, :extipi, :freight_amount, :fuel_detail, :import_control_sheet_number, :import_declarations, :insurance_amount, :item_number_order_buy, :ncm, :number_order_buy, :nve, :others_amount, :quantity, :quantity_tax, :tax, :tax_determination, :tax_unit_amount, :total_amount, :total_indicator, :unit, :unit_amount, :unit_tax, :vehicle_detail) do
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
            import_control_sheet_number: payload["importControlSheetNumber"],
            import_declarations: (payload["importDeclarations"] || []).map { |e| ImportDeclarationResource.from_api(e) },
            insurance_amount: payload["insuranceAmount"],
            item_number_order_buy: payload["itemNumberOrderBuy"],
            ncm: payload["ncm"],
            number_order_buy: payload["numberOrderBuy"],
            nve: payload["nve"],
            others_amount: payload["othersAmount"],
            quantity: payload["quantity"],
            quantity_tax: payload["quantityTax"],
            tax: InvoiceItemTaxResource.from_api(payload["tax"]),
            tax_determination: TaxDeterminationResource.from_api(payload["taxDetermination"]),
            tax_unit_amount: payload["taxUnitAmount"],
            total_amount: payload["totalAmount"],
            total_indicator: payload["totalIndicator"],
            unit: payload["unit"],
            unit_amount: payload["unitAmount"],
            unit_tax: payload["unitTax"],
            vehicle_detail: VehicleDetailResource.from_api(payload["vehicleDetail"]),
          )
        end
      end
    end
  end
end
