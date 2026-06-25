# frozen_string_literal: true

require_relative "name_mapper"

module Nfe
  module Build
    # Compiles an OpenAPI schema declaring "enum: [...]" into an :enum model
    # (frozen-constant module). Returns nil when the schema has no enum key.
    class EnumCompiler
      def initialize(name_mapper: NameMapper)
        @name_mapper = name_mapper
      end

      def compile(schema_name, schema, namespace:, module_path:, source_spec:, spec_hash:)
        return nil unless schema.is_a?(Hash)

        values = schema["enum"]
        return nil unless values.is_a?(Array) && !values.empty?

        backing = backing_for(values)
        {
          kind: :enum,
          const: @name_mapper.class_name(schema_name),
          namespace: namespace,
          module_path: module_path,
          file_snake: @name_mapper.file_snake(schema_name),
          source_spec: source_spec,
          spec_hash: spec_hash,
          backing: backing,
          entries: entries_for(values, backing)
        }
      end

      private

      def backing_for(values)
        values.all?(Integer) ? :integer : :string
      end

      def entries_for(values, backing)
        seen = {}
        values.map do |value|
          base = constant_base(value, backing)
          name = dedupe(base, seen)
          { const_name: name, value: value }
        end
      end

      def constant_base(value, backing)
        return integer_const(value) if backing == :integer

        string_const(value)
      end

      def integer_const(value)
        value.negative? ? "Value_#{value.abs}" : "Value#{value}"
      end

      def string_const(value)
        token = value.to_s.gsub(/[^A-Za-z0-9]+/, " ").strip
        return "Value" if token.empty?

        const = token.split(/\s+/).map { |w| w[0].upcase + w[1..].to_s }.join
        const = "_#{const}" if const.match?(/\A[0-9]/)
        const
      end

      def dedupe(base, seen)
        seen[base] = (seen[base] || 0) + 1
        seen[base] == 1 ? base : "#{base}_#{seen[base]}"
      end
    end
  end
end
