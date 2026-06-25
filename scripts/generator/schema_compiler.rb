# frozen_string_literal: true

require_relative "name_mapper"

module Nfe
  module Build
    # Compiles an OpenAPI object schema into an internal :data or :alias model.
    # Object-with-named-properties -> :data; additionalProperties-only / no
    # named properties -> :alias (Hash[String, untyped]). allOf shallow-merges.
    class SchemaCompiler
      def initialize(type_mapper:, name_mapper: NameMapper)
        @name_mapper = name_mapper
        @type_mapper = type_mapper
      end

      def compile(schema_name, schema, namespace:, module_path:, source_spec:, spec_hash:)
        return nil unless schema.is_a?(Hash)

        properties, required = resolve_properties(schema)
        meta = meta_for(schema_name, namespace, module_path, source_spec, spec_hash)

        return data_model(meta, properties, required) unless properties.empty?
        return alias_model(meta) if free_form_object?(schema)

        nil # bare primitive / array / typeless top-level schema -> no generated file
      end

      private

      def meta_for(schema_name, namespace, module_path, source_spec, spec_hash)
        {
          const: @name_mapper.class_name(schema_name),
          namespace: namespace,
          module_path: module_path,
          file_snake: @name_mapper.file_snake(schema_name),
          source_spec: source_spec,
          spec_hash: spec_hash
        }
      end

      def data_model(meta, properties, required)
        attributes = properties.sort_by(&:first).map do |name, fragment|
          build_attr(name, fragment, required.include?(name))
        end
        meta.merge(kind: :data, attributes: attributes)
      end

      def alias_model(meta)
        meta.merge(kind: :alias, rbs_type: "Hash[String, untyped]")
      end

      # A no-named-properties schema that is still an object (free-form /
      # additionalProperties) is modelled as Hash. Bare primitives/arrays are
      # NOT free-form objects, so the compiler returns nil (no file) for them.
      def free_form_object?(schema)
        schema["type"] == "object" || schema.key?("additionalProperties")
      end

      # Flattens allOf into a single (properties, required) pair. Last member
      # wins on property collision (warn-worthy); required is the union.
      def resolve_properties(schema)
        members = schema.key?("allOf") ? Array(schema["allOf"]) : [schema]
        properties = {}
        required = []
        members.each do |member|
          next unless member.is_a?(Hash)

          properties.merge!(member["properties"]) if member["properties"].is_a?(Hash)
          required.concat(Array(member["required"]))
        end
        [properties, required.uniq]
      end

      def build_attr(original_name, fragment, required)
        fragment = {} unless fragment.is_a?(Hash)
        nullable = fragment["nullable"] == true
        {
          ruby_name: @name_mapper.attr_name(original_name),
          original_name: original_name,
          rbs_type: @type_mapper.rbs_type(fragment),
          nullable: nullable,
          required: required && !nullable,
          ref_target: @type_mapper.ref_target(fragment),
          array_ref_target: @type_mapper.array_ref_target(fragment),
          doc: fragment["description"]
        }
      end
    end
  end
end
