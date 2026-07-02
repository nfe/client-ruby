# frozen_string_literal: true

module Nfe
  module Build
    # Pure, deterministic name derivation: spec filenames -> namespaces/paths,
    # schema names -> Ruby constants/filenames, property names -> attr names.
    #
    # All methods are module_function (call as Nfe::Build::NameMapper.x(...)).
    module NameMapper
      module_function

      RUBY_KEYWORDS = %w[
        BEGIN END alias and begin break case class def defined? do else elsif
        end ensure false for if in module next nil not or redo rescue retry
        return self super then true undef unless until when while yield __FILE__
        __LINE__ __ENCODING__
      ].freeze

      # "service-invoice-rtc-v1.yaml" => "ServiceInvoiceRtcV1"
      def namespace_from_spec(filename)
        stem(filename).split(/[-_.]+/).reject(&:empty?).map { |part| pascal_segment(part) }.join
      end

      # "service-invoice-rtc-v1.yaml" => "service_invoice_rtc_v1"
      def module_path_from_spec(filename)
        stem(filename).split(/[-_.]+/).reject(&:empty?).join("_").downcase
      end

      # Schema name => a valid Ruby/RBS constant. "NFSeRequest" stays as-is;
      # a camelCase name like "ibsCbs" is capitalised to "IbsCbs"; a name that
      # does not start with a letter is prefixed with "N" so the result is always
      # a legal constant (Ruby constants must begin with an uppercase letter).
      def class_name(schema_name)
        const = schema_name.to_s.gsub(/[^A-Za-z0-9_]/, "_")
        const = "N#{const}" unless const.match?(/\A[A-Za-z]/)
        const.sub(/\A[a-z]/, &:upcase)
      end

      # "NFSeRequest" => "nfse_request" (snake_case filename for the const).
      def file_snake(schema_name)
        snake(class_name(schema_name))
      end

      # "federalTaxNumber" => "federal_tax_number" (valid Ruby identifier).
      def attr_name(property_name)
        name = snake(property_name.to_s.gsub(/[^A-Za-z0-9_]/, "_"))
        name = "_#{name}" if name.match?(/\A[0-9]/)
        name = "attr" if name.empty?
        name = "#{name}_" if RUBY_KEYWORDS.include?(name)
        name
      end

      def stem(filename)
        File.basename(filename.to_s, ".*")
      end

      # Pascal-case a single token, preserving version suffix ("v1" => "V1").
      def pascal_segment(part)
        return part.upcase if part.match?(/\A[a-z]\d+\z/)

        part[0].upcase + part[1..]
      end

      # CamelCase/PascalCase -> snake_case. Only a lowercase/digit -> uppercase
      # boundary inserts an underscore, so an acronym run glues to the word it
      # leads ("NFSeRequest" -> "nfse_request", "federalTaxNumber" ->
      # "federal_tax_number").
      def snake(identifier)
        identifier.to_s
                  .gsub(/([a-z\d])([A-Z])/, '\1_\2')
                  .tr("-", "_")
                  .downcase
      end
    end
  end
end
