# frozen_string_literal: true

require_relative "../../scripts/generator/name_mapper"
require_relative "../../scripts/generator/type_mapper"
require_relative "../../scripts/generator/schema_compiler"

RSpec.describe Nfe::Build::SchemaCompiler do
  subject(:compiler) do
    described_class.new(name_mapper: Nfe::Build::NameMapper, type_mapper: type_mapper)
  end

  let(:type_mapper) { Nfe::Build::TypeMapper.new(schema_names: %w[Borrower Address]) }

  def compile(name, schema)
    compiler.compile(
      name, schema,
      namespace: "MinimalV1", module_path: "minimal_v1",
      source_spec: "openapi/minimal.yaml", spec_hash: "sha256:abc"
    )
  end

  describe "#compile object schema" do
    let(:schema) do
      {
        "type" => "object",
        "required" => ["name"],
        "properties" => {
          "name" => { "type" => "string" },
          "federalTaxNumber" => { "type" => "integer" }
        }
      }
    end

    it "produces a :data model carrying namespace and naming metadata" do
      model = compile("Borrower", schema)

      expect(model).to include(
        kind: :data, namespace: "MinimalV1", const: "Borrower",
        module_path: "minimal_v1", file_snake: "borrower",
        source_spec: "openapi/minimal.yaml", spec_hash: "sha256:abc"
      )
    end

    it "orders attributes by name for deterministic output" do
      names = compile("Borrower", schema).fetch(:attributes).map { |a| a[:ruby_name] }

      expect(names).to eq(%w[federal_tax_number name])
    end

    it "maps camelCase properties to snake_case ruby names and keeps the original" do
      attr = compile("Borrower", schema).fetch(:attributes)
                                        .find { |a| a[:original_name] == "federalTaxNumber" }

      expect(attr[:ruby_name]).to eq("federal_tax_number")
    end

    it "marks required properties required and others optional" do
      attrs = compile("Borrower", schema).fetch(:attributes).to_h do |a|
        [a[:ruby_name], a[:required]]
      end

      expect(attrs).to eq("name" => true, "federal_tax_number" => false)
    end
  end

  describe "#compile allOf composition" do
    let(:schema) do
      {
        "allOf" => [
          { "type" => "object", "properties" => { "a" => { "type" => "string" } } },
          { "type" => "object", "properties" => { "b" => { "type" => "integer" } } }
        ]
      }
    end

    it "shallow-merges member properties into one data model" do
      names = compile("Merged", schema).fetch(:attributes).map { |a| a[:ruby_name] }

      expect(names).to contain_exactly("a", "b")
    end
  end

  describe "#compile reserved-word property" do
    let(:schema) do
      { "type" => "object", "properties" => { "class" => { "type" => "string" } } }
    end

    it "renames a reserved-word property to a valid ruby identifier" do
      ruby_name = compile("Reserved", schema).fetch(:attributes).first[:ruby_name]

      expect(ruby_name).to eq("class_")
    end
  end

  describe "#compile free-form object" do
    let(:schema) { { "type" => "object", "additionalProperties" => true } }

    it "falls back to an :alias model of Hash[String, untyped]" do
      model = compile("FreeForm", schema)

      expect(model).to include(kind: :alias, rbs_type: "Hash[String, untyped]")
    end
  end
end
