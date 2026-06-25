# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/contribuintes-v2.json
# Hash: sha256:e2d215a19f5dc85c08067d51644e807aae32b6c4754390872670f2e18a938102

module Nfe
  module Generated
    module ContribuintesV2
      Microsoft_OData_Edm_IEdmModel = Data.define(:declared_namespaces, :direct_value_annotations_manager, :entity_container, :referenced_models, :schema_elements, :vocabulary_annotations) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            declared_namespaces: payload["declaredNamespaces"],
            direct_value_annotations_manager: payload["directValueAnnotationsManager"],
            entity_container: Microsoft_OData_Edm_IEdmEntityContainer.from_api(payload["entityContainer"]),
            referenced_models: (payload["referencedModels"] || []).map { |e| Microsoft_OData_Edm_IEdmModel.from_api(e) },
            schema_elements: (payload["schemaElements"] || []).map { |e| Microsoft_OData_Edm_IEdmSchemaElement.from_api(e) },
            vocabulary_annotations: (payload["vocabularyAnnotations"] || []).map { |e| Microsoft_OData_Edm_Vocabularies_IEdmVocabularyAnnotation.from_api(e) },
          )
        end
      end
    end
  end
end
