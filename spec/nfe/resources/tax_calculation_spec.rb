# frozen_string_literal: true

require "json"

RSpec.describe Nfe::Resources::TaxCalculation do
  subject(:tax_calculation) { client.tax_calculation }

  let(:client) { Nfe::Client.new(api_key: "key", data_api_key: "datakey") }
  let(:transport) { FakeTransport.new }
  let(:valid_request) do
    {
      "operationType" => "OutgoingSale",
      "items" => [{ "productId" => "p-1", "cfop" => 5102 }]
    }
  end

  before { allow(client).to receive(:build_transport).and_return(transport) }

  def response(status: 200, body: "{}", headers: {})
    Nfe::Http::Response.new(status: status, headers: headers, body: body)
  end

  def last_request = transport.requests.last

  describe "routing" do
    it "declares the :cte api_family with an empty version" do
      expect(tax_calculation.send(:api_family)).to eq(:cte)
      expect(tax_calculation.send(:api_version)).to eq("")
    end
  end

  describe "#calculate" do
    let(:payload) do
      {
        "items" => [
          {
            "productId" => "p-1",
            "cfop" => 5102,
            "icms" => { "cst" => "00", "pICMS" => 18.0 },
            "pis" => { "cst" => "01" },
            "cofins" => { "cst" => "01" },
            "ipi" => { "cst" => "50" },
            "ii" => { "vII" => 0.0 }
          }
        ]
      }
    end

    before { transport.enqueue(response(body: payload.to_json)) }

    it "POSTs to the URL-encoded tax-rules engine path on api.nfse.io" do
      tax_calculation.calculate("tenant 7/x", valid_request)

      expect(last_request.method).to eq("POST")
      expect(last_request.url).to start_with("https://api.nfse.io")
      expect(last_request.url).to end_with("/tax-rules/tenant+7%2Fx/engine/calculate")
    end

    it "sends the request as JSON with a JSON Content-Type" do
      tax_calculation.calculate("tenant-7", valid_request)

      expect(last_request.headers["Content-Type"]).to eq("application/json")
      expect(JSON.parse(last_request.body)).to eq(valid_request)
    end

    it "hydrates a generated CalculateResponse with a per-item tax breakdown" do
      result = tax_calculation.calculate("tenant-7", valid_request)

      expect(result).to be_a(Nfe::Generated::CalculoImpostosV1::CalculateResponse)
      item = result.items.first
      expect(item).to be_a(Nfe::Generated::CalculoImpostosV1::CalculateItemResponse)
      expect(item.cfop).to eq(5102)
      expect(item.icms).to be_a(Nfe::Generated::CalculoImpostosV1::Icms)
      expect(item.icms.cst).to eq("00")
      expect(item.pis.cst).to eq("01")
      expect(item.cofins.cst).to eq("01")
      expect(item.ipi.cst).to eq("50")
    end

    it "accepts a snake_case operation_type key" do
      tax_calculation.calculate("tenant-7", { operation_type: "OutgoingSale", items: [{}] })
      expect(last_request.method).to eq("POST")
    end
  end

  describe "#calculate validation (no HTTP)" do
    it "rejects an empty tenant_id before any HTTP request" do
      expect { tax_calculation.calculate("  ", valid_request) }
        .to raise_error(Nfe::InvalidRequestError)
      expect(transport.requests).to be_empty
    end

    it "rejects an empty items array before any HTTP request" do
      expect { tax_calculation.calculate("tenant-7", { "operationType" => "OutgoingSale", "items" => [] }) }
        .to raise_error(Nfe::InvalidRequestError)
      expect(transport.requests).to be_empty
    end

    it "rejects a request missing operationType before any HTTP request" do
      expect { tax_calculation.calculate("tenant-7", { "items" => [{}] }) }
        .to raise_error(Nfe::InvalidRequestError)
      expect(transport.requests).to be_empty
    end

    it "rejects a non-Hash request before any HTTP request" do
      expect { tax_calculation.calculate("tenant-7", []) }
        .to raise_error(Nfe::InvalidRequestError)
      expect(transport.requests).to be_empty
    end
  end
end
