# frozen_string_literal: true

require_relative "../../scripts/generator/name_mapper"
require_relative "../../scripts/generator/type_mapper"
require_relative "../../scripts/generator/schema_compiler"
require_relative "../../scripts/generator/enum_compiler"
require_relative "../../scripts/generator/ruby_emitter"

RSpec.describe Nfe::Build::RubyEmitter do
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
        "federalTaxNumber" => { "type" => "integer" }
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

  def eval_in_anon_module(source)
    mod = Module.new
    mod.module_eval(source, "(generated)", 1)
    mod
  end

  describe ".emit data model" do
    subject(:source) { described_class.emit(data_model("Borrower", object_schema)) }

    it "puts the frozen_string_literal magic comment on line 1" do
      expect(source.lines.first.chomp).to eq("# frozen_string_literal: true")
    end

    it "carries the AUTO-GENERATED banner with source and hash" do
      expect(source).to include("# AUTO-GENERATED")
      expect(source).to include("# Source: openapi/minimal.yaml")
      expect(source).to include("# Hash: sha256:abc")
    end

    it "declares a Data.define with the snake_case members" do
      expect(source).to include("Data.define(")
      expect(source).to include(":name")
      expect(source).to include(":federal_tax_number")
    end

    it "emits a from_api class method" do
      expect(source).to include("def self.from_api")
    end

    it "records the original camelCase name for traceability" do
      expect(source).to include("federalTaxNumber")
    end

    it "evals into a loadable constant under Nfe::Generated" do
      mod = eval_in_anon_module(source)
      const = mod.const_get(:Nfe).const_get(:Generated).const_get(:MinimalV1).const_get(:Borrower)

      expect(const.members).to contain_exactly(:name, :federal_tax_number)
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

    it "emits frozen constants and an ALL array" do
      expect(source).to include("Issued = \"Issued\"")
      expect(source).to include("Cancelled = \"Cancelled\"")
      expect(source).to include("ALL = [")
    end

    it "evals into a module exposing the enum constants" do
      mod = eval_in_anon_module(source)
      enum = mod.const_get(:Nfe).const_get(:Generated).const_get(:MinimalV1).const_get(:InvoiceStatus)

      expect(enum::ALL).to contain_exactly("Issued", "Cancelled")
    end
  end

  describe ".emit alias model" do
    subject(:source) do
      model = schema_compiler.compile(
        "FreeForm", { "type" => "object", "additionalProperties" => true },
        namespace: "MinimalV1", module_path: "minimal_v1",
        source_spec: "openapi/minimal.yaml", spec_hash: "sha256:abc"
      )
      described_class.emit(model)
    end

    it "emits a thin Hash assignment and loads" do
      expect(source.lines.first.chomp).to eq("# frozen_string_literal: true")
      mod = eval_in_anon_module(source)
      const = mod.const_get(:Nfe).const_get(:Generated).const_get(:MinimalV1).const_get(:FreeForm)

      expect(const).to eq(Hash)
    end
  end
end
