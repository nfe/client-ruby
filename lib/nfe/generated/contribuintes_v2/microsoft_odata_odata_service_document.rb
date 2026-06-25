# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/contribuintes-v2.json
# Hash: sha256:e2d215a19f5dc85c08067d51644e807aae32b6c4754390872670f2e18a938102

module Nfe
  module Generated
    module ContribuintesV2
      Microsoft_OData_ODataServiceDocument = Data.define(:entity_sets, :function_imports, :singletons, :type_annotation) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            entity_sets: (payload["entitySets"] || []).map { |e| Microsoft_OData_ODataEntitySetInfo.from_api(e) },
            function_imports: (payload["functionImports"] || []).map { |e| Microsoft_OData_ODataFunctionImportInfo.from_api(e) },
            singletons: (payload["singletons"] || []).map { |e| Microsoft_OData_ODataSingletonInfo.from_api(e) },
            type_annotation: Microsoft_OData_ODataTypeAnnotation.from_api(payload["typeAnnotation"]),
          )
        end
      end
    end
  end
end
