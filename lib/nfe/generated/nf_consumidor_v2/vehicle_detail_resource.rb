# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/nf-consumidor-v2.yaml
# Hash: sha256:8c39e692ff794ccb2587ebe142be040e44d76cbf970f45e65b28d56a6165bdb5

module Nfe
  module Generated
    module NfConsumidorV2
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
