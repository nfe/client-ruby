# frozen_string_literal: true

require_relative "../../scripts/generator/name_mapper"
require_relative "../../scripts/generator/type_mapper"
require_relative "../../scripts/generator/schema_compiler"
require_relative "../../scripts/generator/ruby_emitter"

RSpec.describe Nfe::Build::RubyEmitter, ".emit" do
  # Exercises the generated `from_api` hydration on the emitted Data classes.
  let(:schemas) do
    {
      "Borrower" => {
        "type" => "object",
        "required" => ["name"],
        "properties" => {
          "name" => { "type" => "string" },
          "federalTaxNumber" => { "type" => "integer" },
          "address" => { "$ref" => "#/components/schemas/Address" },
          "documents" => {
            "type" => "array",
            "items" => { "$ref" => "#/components/schemas/Document" }
          }
        }
      },
      "Address" => {
        "type" => "object",
        "properties" => { "city" => { "type" => "string" } }
      },
      "Document" => {
        "type" => "object",
        "properties" => { "kind" => { "type" => "string" } }
      }
    }
  end

  # Eval all DTOs into one anonymous module so $ref hydration resolves the
  # sibling constants (Address.from_api, Document.from_api).
  let(:namespace_module) do
    type_mapper = Nfe::Build::TypeMapper.new(schema_names: schemas.keys)
    compiler = Nfe::Build::SchemaCompiler.new(
      name_mapper: Nfe::Build::NameMapper, type_mapper: type_mapper
    )
    mod = Module.new
    schemas.each do |name, schema|
      model = compiler.compile(
        name, schema,
        namespace: "MinimalV1", module_path: "minimal_v1",
        source_spec: "openapi/minimal.yaml", spec_hash: "sha256:abc"
      )
      mod.module_eval(described_class.emit(model), "(generated #{name})", 1)
    end
    mod.const_get(:Nfe).const_get(:Generated).const_get(:MinimalV1)
  end

  let(:borrower) { namespace_module.const_get(:Borrower) }

  it "returns nil for a nil payload" do
    expect(borrower.from_api(nil)).to be_nil
  end

  it "maps camelCase keys to snake_case members" do
    instance = borrower.from_api("name" => "Acme", "federalTaxNumber" => 123)

    expect(instance.name).to eq("Acme")
    expect(instance.federal_tax_number).to eq(123)
  end

  it "drops unknown keys without raising" do
    instance = borrower.from_api("name" => "Acme", "surpriseField" => "x")

    expect(instance.name).to eq("Acme")
  end

  it "tolerates missing keys, leaving them nil" do
    instance = borrower.from_api("name" => "Acme")

    expect(instance.federal_tax_number).to be_nil
  end

  it "hydrates a nested $ref object into its DTO" do
    instance = borrower.from_api("name" => "Acme", "address" => { "city" => "Sao Paulo" })

    expect(instance.address).to be_a(namespace_module.const_get(:Address))
    expect(instance.address.city).to eq("Sao Paulo")
  end

  it "hydrates an array of $ref element-by-element" do
    instance = borrower.from_api(
      "name" => "Acme",
      "documents" => [{ "kind" => "RG" }, { "kind" => "CPF" }]
    )

    expect(instance.documents).to all(be_a(namespace_module.const_get(:Document)))
    expect(instance.documents.map(&:kind)).to eq(%w[RG CPF])
  end
end
