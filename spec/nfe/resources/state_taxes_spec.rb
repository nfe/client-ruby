# frozen_string_literal: true

require "json"

RSpec.describe Nfe::Resources::StateTaxes do
  subject(:state_taxes) { client.state_taxes }

  let(:client) { Nfe::Client.new(api_key: "key", data_api_key: "datakey") }
  let(:transport) { FakeTransport.new }
  let(:company_id) { "co_123" }
  let(:state_tax_body) { { "code" => "SP", "taxNumber" => "1234567890" } }

  before { allow(client).to receive(:build_transport).and_return(transport) }

  def response(status: 200, body: "{}", headers: {})
    Nfe::Http::Response.new(status: status, headers: headers, body: body)
  end

  def last_request = transport.requests.last

  describe "#create" do
    before { transport.enqueue(response(body: { "stateTax" => { "id" => "st_1", "code" => "SP" } }.to_json)) }

    it "POSTs the stateTax-wrapped body as JSON to the api.nfse.io host" do
      result = state_taxes.create(company_id, state_tax_body)

      expect(result).to be_a(Nfe::NfeStateTax)
      expect(result.id).to eq("st_1")
      expect(last_request.method).to eq("POST")
      expect(last_request.url).to start_with("https://api.nfse.io")
      expect(last_request.url).to include("/v2/companies/#{company_id}/statetaxes")
      expect(last_request.headers["Content-Type"]).to eq("application/json")
      expect(JSON.parse(last_request.body)).to eq("stateTax" => state_tax_body)
    end

    it "raises before HTTP when company_id is empty" do
      expect { state_taxes.create("", state_tax_body) }.to raise_error(Nfe::InvalidRequestError)
      expect(transport.requests).to be_empty
    end
  end

  describe "#update" do
    before { transport.enqueue(response(body: { "stateTax" => { "id" => "st_1" } }.to_json)) }

    it "PUTs the stateTax-wrapped body as JSON to the id path" do
      result = state_taxes.update(company_id, "st_1", state_tax_body)

      expect(result).to be_a(Nfe::NfeStateTax)
      expect(last_request.method).to eq("PUT")
      expect(last_request.url).to include("/v2/companies/#{company_id}/statetaxes/st_1")
      expect(JSON.parse(last_request.body)).to eq("stateTax" => state_tax_body)
    end
  end

  describe "#list" do
    before do
      transport.enqueue(response(body: {
        "stateTaxes" => [{ "id" => "st_1" }, { "id" => "st_2" }],
        "startingAfter" => "st_1"
      }.to_json))
    end

    it "returns a cursor-style ListResponse on the api.nfse.io host" do
      result = state_taxes.list(company_id, limit: 50)

      expect(result).to be_a(Nfe::ListResponse)
      expect(result.data.map(&:id)).to eq(%w[st_1 st_2])
      expect(result.data.first).to be_a(Nfe::NfeStateTax)
      expect(result.page.starting_after).to eq("st_1")
      expect(result.page.page_index).to be_nil
      expect(last_request.method).to eq("GET")
      expect(last_request.url).to start_with("https://api.nfse.io")
      expect(last_request.url).to include("/v2/companies/#{company_id}/statetaxes")
      expect(last_request.url).to include("limit=50")
    end
  end

  describe "#retrieve" do
    before { transport.enqueue(response(body: { "stateTax" => { "id" => "st_9" } }.to_json)) }

    it "GETs the id path and hydrates NfeStateTax" do
      result = state_taxes.retrieve(company_id, "st_9")

      expect(result).to be_a(Nfe::NfeStateTax)
      expect(result.id).to eq("st_9")
      expect(last_request.method).to eq("GET")
      expect(last_request.url).to include("/v2/companies/#{company_id}/statetaxes/st_9")
    end

    it "raises before HTTP when state_tax_id is empty" do
      expect { state_taxes.retrieve(company_id, "") }.to raise_error(Nfe::InvalidRequestError)
      expect(transport.requests).to be_empty
    end
  end

  describe "#delete" do
    before { transport.enqueue(response(status: 204, body: "")) }

    it "DELETEs the id path and returns nil" do
      result = state_taxes.delete(company_id, "st_9")

      expect(result).to be_nil
      expect(last_request.method).to eq("DELETE")
      expect(last_request.url).to include("/v2/companies/#{company_id}/statetaxes/st_9")
    end

    it "raises before HTTP when company_id is empty" do
      expect { state_taxes.delete("", "st_9") }.to raise_error(Nfe::InvalidRequestError)
      expect(transport.requests).to be_empty
    end
  end
end
