# frozen_string_literal: true

require "yaml"

# Alignment test pinning Nfe::ServiceInvoice to the NFS-e retrieve contract in
# the official OpenAPI spec (openapi/nf-servico-v1.yaml). The success response
# is declared INLINE (only the error model is componentized), so the DTO is
# hand-written — this spec keeps it honest against the schema, and doubles as
# the migration tripwire: when the upstream componentizes the response (the
# inline schema becomes a $ref), the path-anchored dig fails loudly as the
# signal to migrate to the generated model.
#
# Anchored by PATH, not by operationId: ServiceInvoices_idGet collides between
# /serviceinvoices/{id} and /serviceinvoices/external/{id}.
RSpec.describe Nfe::ServiceInvoice do
  let(:openapi) do
    YAML.safe_load_file(File.expand_path("../../../../openapi/nf-servico-v1.yaml", __dir__))
  end

  let(:retrieve_schema) do
    openapi.dig(
      "paths", "/v1/companies/{company_id}/serviceinvoices/{id}", "get",
      "responses", "200", "content", "application/json", "schema"
    )
  end

  let(:schema_fields) { retrieve_schema.fetch("properties") }

  # Members that deliberately have no schema counterpart: the raw escape-hatch
  # and the deprecated ghosts (pinned below).
  let(:unmapped_members) { %i[raw pdf xml] }

  def snake_case(camel)
    camel.gsub(/([A-Z])/) { "_#{Regexp.last_match(1).downcase}" }
  end

  it "anchors the inline retrieve schema by path (componentization tripwire)" do
    expect(retrieve_schema).to be_a(Hash), "retrieve schema not found at the anchored path"
    expect(retrieve_schema["properties"]).to be_a(Hash),
                                             "retrieve 200 schema is no longer inline (componentized upstream?) — " \
                                             "time to migrate Nfe::ServiceInvoice to the generated model"
  end

  it "maps every typed member to a schema property" do
    typed = described_class.members - unmapped_members
    spec_fields = schema_fields.keys.map { |key| snake_case(key).to_sym }

    expect(typed - spec_fields).to be_empty,
                                   "typed members absent from the spec: #{(typed - spec_fields).join(', ')}"
  end

  # Deliberate deviation, pinned: pdf/xml are ghost members kept only for
  # backward compatibility (@deprecated) — the retrieve response has no such
  # fields. If a spec sync adds them, drop the deprecation instead.
  it "pins the pdf/xml ghosts as absent from the schema" do
    expect(schema_fields.keys).not_to include("pdf", "xml")
  end

  it "maps every typed Borrower member to the borrower sub-schema" do
    borrower_fields = schema_fields.fetch("borrower").fetch("properties")
    typed = Nfe::ServiceInvoiceBorrower.members - %i[raw]
    spec_fields = borrower_fields.keys.map { |key| snake_case(key).to_sym }

    expect(typed - spec_fields).to be_empty,
                                   "Borrower members absent from the spec: #{(typed - spec_fields).join(', ')}"
  end

  # Deliberate deviation, pinned: the spec declares borrower.federalTaxNumber
  # as an int64, but the alphanumeric CNPJ (IN RFB 2.229/2024) requires string
  # tolerance — the DTO normalizes to String via Company.stringify. If a spec
  # sync turns this into a string, this test fails as the signal to drop the
  # deviation note.
  it "pins the borrower.federalTaxNumber int-enum deviation (DTO normalizes to String)" do
    federal = schema_fields.fetch("borrower").fetch("properties").fetch("federalTaxNumber")
    expect(federal["type"]).to eq("integer"),
                               "federalTaxNumber is no longer an integer in the spec — " \
                               "drop the wire-deviation pin and revisit the stringify note"
    expect(federal["format"]).to eq("int64")
  end
end
