# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/product-invoice-rtc-v1.yaml
# Hash: sha256:4327ad141eeace6219dc4267678c44a134ae1fdde93f7dd69cf4c9ae9418415a

module Nfe
  module Generated
    module ProductInvoiceRtcV1
      VehicleDetailResource = Data.define(:brand_model_code, :chassis, :color_code, :color_description, :denatran_color_code, :engine_displacement, :engine_number, :engine_power, :fuel_type, :gross_weight, :manufacture_year, :maximum_traction_capacity, :model_year, :net_weight, :operation_type, :paint_type, :restriction_type, :seating_capacity, :serial_number, :vehicle_condition, :vehicle_species, :vehicle_type, :vin_condition, :wheel_base) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            brand_model_code: payload["brandModelCode"],
            chassis: payload["chassis"],
            color_code: payload["colorCode"],
            color_description: payload["colorDescription"],
            denatran_color_code: payload["denatranColorCode"],
            engine_displacement: payload["engineDisplacement"],
            engine_number: payload["engineNumber"],
            engine_power: payload["enginePower"],
            fuel_type: payload["fuelType"],
            gross_weight: payload["grossWeight"],
            manufacture_year: payload["manufactureYear"],
            maximum_traction_capacity: payload["maximumTractionCapacity"],
            model_year: payload["modelYear"],
            net_weight: payload["netWeight"],
            operation_type: payload["operationType"],
            paint_type: payload["paintType"],
            restriction_type: payload["restrictionType"],
            seating_capacity: payload["seatingCapacity"],
            serial_number: payload["serialNumber"],
            vehicle_condition: payload["vehicleCondition"],
            vehicle_species: payload["vehicleSpecies"],
            vehicle_type: payload["vehicleType"],
            vin_condition: payload["vinCondition"],
            wheel_base: payload["wheelBase"],
          )
        end
      end
    end
  end
end
