# frozen_string_literal: true

require "yaml"

# Alignment test pinning Nfe::AccountWebhook to the /v2/webhooks contract in
# the official OpenAPI spec (openapi/nf-servico-v1.yaml). A spec sync that
# changes the webhook contract fails this suite instead of silently drifting —
# the contract source of truth is the OpenAPI spec plus live probes, never a
# sibling SDK.
RSpec.describe Nfe::AccountWebhook do
  let(:openapi) do
    YAML.safe_load_file(File.expand_path("../../../../openapi/nf-servico-v1.yaml", __dir__))
  end

  let(:item_schema) do
    openapi.dig(
      "paths", "/v2/webhooks", "get", "responses", "200", "content",
      "application/json", "schema", "properties", "webHooks", "items"
    )
  end

  let(:request_schema) do
    openapi.dig(
      "paths", "/v2/webhooks", "post", "requestBody", "content",
      "application/json", "schema"
    )
  end

  def snake_case(camel)
    camel.gsub(/([A-Z])/) { "_#{Regexp.last_match(1).downcase}" }
  end

  it "wraps the create request body in a webHook envelope" do
    expect(request_schema["properties"].keys).to eq(["webHook"])
  end

  it "covers every field of the /v2/webhooks item schema" do
    spec_fields = item_schema["properties"].keys.map { |key| snake_case(key) }.sort
    members = described_class.members.map(&:to_s).sort

    expect(spec_fields - members).to be_empty,
                                     "spec fields missing from the DTO: #{(spec_fields - members).join(', ')}"
    expect(members - spec_fields).to be_empty,
                                     "DTO members absent from the spec: #{(members - spec_fields).join(', ')}"
  end

  # Deliberate deviation, pinned: the spec declares contentType/status as int
  # enums (0/1), but the live API serializes strings ("json", "Active") — the
  # DTO follows the wire. If a spec sync turns these into strings, this test
  # fails as the signal to drop the deviation note from the DTO docs.
  it "pins the contentType/status int-enum deviation (wire serializes strings)" do
    %w[contentType status].each do |field|
      schema = item_schema["properties"].fetch(field)
      expect(schema["type"]).to eq("integer"),
                                "#{field} is no longer an int enum in the spec — " \
                                "drop the wire-deviation pin and revisit the DTO docs"
      expect(schema["enum"]).to eq([0, 1])
    end
  end
end
