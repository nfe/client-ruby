# frozen_string_literal: true

require "json"
require "date"

RSpec.describe Nfe::Resources::NaturalPersonLookup do
  subject(:natural_person_lookup) { client.natural_person_lookup }

  let(:client) { Nfe::Client.new(api_key: "key", data_api_key: "datakey") }
  let(:transport) { FakeTransport.new }

  before { allow(client).to receive(:build_transport).and_return(transport) }

  def response(status: 200, body: "{}", headers: {})
    Nfe::Http::Response.new(status: status, headers: headers, body: body)
  end

  def last_request = transport.requests.last

  describe "#get_status" do
    it "targets the naturalperson data host" do
      transport.enqueue(response(body: { "name" => "Fulano" }.to_json))
      natural_person_lookup.get_status("123.456.789-01", "1990-01-15")
      expect(last_request.url).to start_with("https://naturalperson.api.nfe.io")
    end

    it "normalizes the CPF to digits-only in the path" do
      transport.enqueue(response(body: "{}"))
      natural_person_lookup.get_status("123.456.789-01", "1990-01-15")
      expect(last_request.url).to include("/v1/naturalperson/status/12345678901/1990-01-15")
    end

    it "produces the same path for an ISO String and a Date birth_date" do
      transport.enqueue(response(body: "{}"))
      natural_person_lookup.get_status("12345678901", "1990-01-15")
      string_url = last_request.url

      natural_person_lookup.get_status("12345678901", Date.new(1990, 1, 15))
      date_url = last_request.url

      expect(date_url).to eq(string_url)
    end

    it "hydrates the status response" do
      transport.enqueue(response(body: {
        "name" => "Fulano de Tal",
        "federalTaxNumber" => "12345678901",
        "birthOn" => "1990-01-15",
        "status" => "Regular",
        "createdOn" => "2026-01-01T00:00:00Z"
      }.to_json))

      result = natural_person_lookup.get_status("12345678901", "1990-01-15")

      expect(result).to be_a(Nfe::NaturalPersonStatusResponse)
      expect(result.name).to eq("Fulano de Tal")
      expect(result.federal_tax_number).to eq("12345678901")
      expect(result.status).to eq("Regular")
    end

    it "rejects a non-ISO birth_date before HTTP" do
      expect { natural_person_lookup.get_status("12345678901", "15/01/1990") }
        .to raise_error(Nfe::InvalidRequestError)
      expect(transport.requests).to be_empty
    end

    it "rejects an out-of-range birth_date before HTTP" do
      expect { natural_person_lookup.get_status("12345678901", "2026-13-45") }
        .to raise_error(Nfe::InvalidRequestError)
      expect(transport.requests).to be_empty
    end

    it "rejects an invalid CPF before HTTP" do
      expect { natural_person_lookup.get_status("123", "1990-01-15") }
        .to raise_error(Nfe::InvalidRequestError)
      expect(transport.requests).to be_empty
    end
  end
end
