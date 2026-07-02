# frozen_string_literal: true

require_relative "name_mapper"

module Nfe
  module Build
    # Maps an OpenAPI schema fragment to an RBS type string. Conservative:
    # ambiguous/complex constructs fall back to "untyped" rather than fail.
    class TypeMapper
      PRIMITIVES = {
        "string" => "String",
        "integer" => "Integer",
        "number" => "Float",
        "boolean" => "bool"
      }.freeze

      LOCAL_REF = %r{\A#/components/schemas/(.+)\z}

      def initialize(schema_names:, schemas: {})
        @schema_names = schema_names.to_a.to_set { |n| NameMapper.class_name(n) }
        @schemas = schemas
        @warnings = []
      end

      attr_reader :warnings

      def rbs_type(fragment)
        return "untyped" unless fragment.is_a?(Hash)

        base = base_rbs_type(fragment)
        nullable?(fragment) ? nullable(base) : base
      end

      # Referenced class name when fragment is a local $ref to a known schema.
      def ref_target(fragment)
        return nil unless fragment.is_a?(Hash)

        ref = fragment["$ref"]
        return nil unless ref.is_a?(String)

        match = LOCAL_REF.match(ref)
        return nil unless match

        const = NameMapper.class_name(match[1])
        return nil unless @schema_names.include?(const)

        target = @schemas[match[1]]
        return const if target.nil? # no schema map (unit tests): assume a generated class

        data_class?(target) ? const : nil
      end

      # Item class name when fragment is an array whose items is a known $ref.
      def array_ref_target(fragment)
        return nil unless fragment.is_a?(Hash) && fragment["type"] == "array"

        ref_target(fragment["items"])
      end

      private

      def base_rbs_type(fragment)
        return ref_rbs(fragment) if fragment.key?("$ref")
        return one_of_rbs(fragment) if fragment.key?("oneOf") || fragment.key?("anyOf")
        return "untyped" if fragment.key?("allOf")

        type = fragment["type"]
        return array_rbs(fragment) if type == "array"
        return object_rbs(fragment) if type == "object"
        return PRIMITIVES[type] if PRIMITIVES.key?(type)

        "untyped"
      end

      def ref_rbs(fragment)
        ref = fragment["$ref"]
        match = LOCAL_REF.match(ref.to_s)
        unless match
          warn("cross-file or unresolved $ref: #{ref.inspect}")
          return "untyped"
        end

        resolve_ref_type(match[1])
      end

      # Resolve a local $ref to the RBS type the target schema actually compiles
      # to: a Data class for object schemas, the primitive for bare primitives,
      # Hash for free-form objects, and untyped for enums / unknowns.
      def resolve_ref_type(name)
        const = NameMapper.class_name(name)
        target = @schemas[name]
        if target.is_a?(Hash)
          return const if data_class?(target)
          return "untyped" if target.key?("enum") || target.key?("$ref")

          return rbs_type(target)
        end
        return const if @schema_names.include?(const)

        warn("unknown local $ref: ##{name}")
        "untyped"
      end

      # A schema that compiles to a generated Data class (object with named
      # properties, or an allOf composition) — distinct from enums, free-form
      # objects (Hash), and bare primitives.
      def data_class?(schema)
        return false unless schema.is_a?(Hash)
        return false if schema.key?("enum")

        props = schema["properties"]
        (props.is_a?(Hash) && !props.empty?) || schema.key?("allOf")
      end

      def array_rbs(fragment)
        items = fragment["items"]
        return "Array[untyped]" unless items.is_a?(Hash)

        "Array[#{rbs_type(items)}]"
      end

      def object_rbs(_fragment)
        "Hash[String, untyped]"
      end

      def one_of_rbs(fragment)
        members = fragment["oneOf"] || fragment["anyOf"]
        return "untyped" unless members.is_a?(Array) && !members.empty?

        return "untyped" unless members.all? { |m| primitive_member?(m) }

        members.map { |m| PRIMITIVES[m["type"]] }.uniq.join(" | ")
      end

      def primitive_member?(member)
        member.is_a?(Hash) && PRIMITIVES.key?(member["type"])
      end

      def nullable?(fragment)
        fragment["nullable"] == true
      end

      def nullable(base)
        base.end_with?("?") || base == "untyped" ? base : "#{base}?"
      end

      def warn(message)
        @warnings << message
      end
    end
  end
end
