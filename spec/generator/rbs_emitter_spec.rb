# frozen_string_literal: true

require_relative "../../scripts/generator/name_mapper"
require_relative "../../scripts/generator/type_mapper"
require_relative "../../scripts/generator/schema_compiler"
require_relative "../../scripts/generator/enum_compiler"
require_relative "../../scripts/generator/rbs_emitter"

RSpec.describe Nfe::Build::RbsEmitter do
  let(:type_mapper) { Nfe::Build::TypeMapper.new(schema_names: %w[Borrower Address]) }
  let(:schema_compiler) do
    Nfe::Build::SchemaCompiler.new(name_mapper: Nfe::Build::NameMapper, type_mapper: type_mapper)
  end
  let(:enum_compiler) { Nfe::Build::EnumCompiler.new(name_mapper: Nfe::Build::NameMapper) }

  let(:object_schema) do
    {
      "type" => "object",
      "required" => ["name"],
      "properties" => {
        "name" => { "type" => "string" },
        "federalTaxNumber" => { "type" => "integer" },
        "email" => { "type" => "string", "nullable" => true }
      }
    }
  end

  def data_model(name, schema)
    schema_compiler.compile(
      name, schema,
      namespace: "MinimalV1", module_path: "minimal_v1",
      source_spec: "openapi/minimal.yaml", spec_hash: "sha256:abc"
    )
  end

  def rbs_parses?(source)
    require "rbs"
    RBS::Parser.parse_signature(source)
    true
  rescue LoadError
    :skip
  end

  describe ".emit data model" do
    subject(:source) { described_class.emit(data_model("Borrower", object_schema)) }

    it "carries the AUTO-GENERATED comment banner with source and hash" do
      expect(source).to include("# AUTO-GENERATED")
      expect(source).to include("# Source: openapi/minimal.yaml")
      expect(source).to include("# Hash: sha256:abc")
    end

    it "declares the class under the generated namespace" do
      expect(source).to include("module Nfe")
      expect(source).to include("module Generated")
      expect(source).to include("module MinimalV1")
      expect(source).to include("class Borrower < Data")
    end

    it "mirrors the .rb members as typed attr_readers" do
      expect(source).to include("attr_reader name: String")
      expect(source).to include("attr_reader federal_tax_number: Integer")
    end

    it "types an optional/nullable property as nullable" do
      expect(source).to include("email: String?")
    end

    it "declares the from_api signature" do
      expect(source).to include("def self.from_api:")
      expect(source).to include("instance")
    end

    it "is valid RBS syntax when the rbs gem is available" do
      result = rbs_parses?(source)
      skip "rbs gem not available" if result == :skip

      expect(result).to be(true)
    end
  end

  describe ".emit enum model" do
    subject(:source) do
      model = enum_compiler.compile(
        "InvoiceStatus", { "type" => "string", "enum" => %w[Issued Cancelled] },
        namespace: "MinimalV1", module_path: "minimal_v1",
        source_spec: "openapi/minimal.yaml", spec_hash: "sha256:abc"
      )
      described_class.emit(model)
    end

    it "declares the enum constants and ALL" do
      expect(source).to include("Issued")
      expect(source).to include("Cancelled")
      expect(source).to include("ALL")
    end

    it "is valid RBS syntax when the rbs gem is available" do
      result = rbs_parses?(source)
      skip "rbs gem not available" if result == :skip

      expect(result).to be(true)
    end
  end
end
