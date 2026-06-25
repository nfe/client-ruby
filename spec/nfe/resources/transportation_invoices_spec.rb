# frozen_string_literal: true

require "json"

RSpec.describe Nfe::Resources::TransportationInvoices do
  subject(:resource) { client.transportation_invoices }

  let(:client) { Nfe::Client.new(api_key: "key", data_api_key: "data-key") }
  let(:transport) { FakeTransport.new }
  let(:access_key) { "3" * 44 }

  before { allow(client).to receive(:build_transport).and_return(transport) }

  def json(status: 200, body: "{}", headers: {})
    Nfe::Http::Response.new(status: status, headers: headers, body: body)
  end

  def last_request
    transport.requests.last
  end

  describe "#enable" do
    before { transport.enqueue(json(body: { "id" => "s1", "status" => "Active" }.to_json)) }

    it "POSTs to api.nfse.io and returns hydrated settings" do
      settings = resource.enable(company_id: "co-1", start_from_nsu: 42)

      expect(settings).to be_a(Nfe::InboundSettings)
      expect(settings.status).to eq("Active")
      expect(last_request.method).to eq("POST")
      expect(last_request.url).to eq("https://api.nfse.io/v2/companies/co-1/inbound/transportationinvoices")
      expect(JSON.parse(last_request.body)).to eq({ "startFromNsu" => 42 })
      expect(last_request.headers["Content-Type"]).to eq("application/json")
    end

    it "omits nil optional fields from the body" do
      resource.enable(company_id: "co-1")
      expect(JSON.parse(last_request.body)).to eq({})
    end

    it "rejects an empty company_id without HTTP" do
      expect { resource.enable(company_id: " ") }.to raise_error(Nfe::InvalidRequestError)
      expect(transport.requests).to be_empty
    end
  end

  describe "#disable" do
    it "DELETEs and returns settings" do
      transport.enqueue(json(body: { "status" => "Disabled" }.to_json))
      settings = resource.disable(company_id: "co-1")

      expect(settings.status).to eq("Disabled")
      expect(last_request.method).to eq("DELETE")
      expect(last_request.url).to eq("https://api.nfse.io/v2/companies/co-1/inbound/transportationinvoices")
    end
  end

  describe "#get_settings" do
    it "GETs the current settings" do
      transport.enqueue(json(body: { "status" => "Active", "webhookVersion" => "2" }.to_json))
      settings = resource.get_settings(company_id: "co-1")

      expect(settings.webhook_version).to eq("2")
      expect(last_request.method).to eq("GET")
      expect(last_request.url).to eq("https://api.nfse.io/v2/companies/co-1/inbound/transportationinvoices")
    end
  end

  describe "#retrieve" do
    it "normalises a formatted access key to 44 digits in the path" do
      transport.enqueue(json(body: { "accessKey" => access_key, "nameSender" => "Transp" }.to_json))
      formatted = access_key.scan(/.{4}/).join(" ")

      cte = resource.retrieve(company_id: "co-1", access_key: formatted)

      expect(cte).to be_a(Nfe::InboundInvoiceMetadata)
      expect(cte.name_sender).to eq("Transp")
      expect(last_request.url).to eq("https://api.nfse.io/v2/companies/co-1/inbound/#{access_key}")
    end

    it "rejects a wrong-length access key without HTTP" do
      expect { resource.retrieve(company_id: "co-1", access_key: "123") }
        .to raise_error(Nfe::InvalidRequestError)
      expect(transport.requests).to be_empty
    end
  end

  describe "#download_xml" do
    it "returns binary XML bytes with an XML Accept header" do
      transport.enqueue(json(body: "<cteProc>x</cteProc>"))
      xml = resource.download_xml(company_id: "co-1", access_key: access_key)

      expect(xml).to start_with("<")
      expect(xml.encoding).to eq(Encoding::ASCII_8BIT)
      expect(last_request.url).to eq("https://api.nfse.io/v2/companies/co-1/inbound/#{access_key}/xml")
      expect(last_request.headers["Accept"]).to eq("application/xml")
    end
  end

  describe "#get_event" do
    it "GETs the event metadata" do
      transport.enqueue(json(body: { "status" => "Authorized" }.to_json))
      event = resource.get_event(company_id: "co-1", access_key: access_key, event_key: "ev-9")

      expect(event).to be_a(Nfe::InboundInvoiceMetadata)
      expect(last_request.url)
        .to eq("https://api.nfse.io/v2/companies/co-1/inbound/#{access_key}/events/ev-9")
    end

    it "rejects an empty event_key without HTTP" do
      expect { resource.get_event(company_id: "co-1", access_key: access_key, event_key: "") }
        .to raise_error(Nfe::InvalidRequestError)
      expect(transport.requests).to be_empty
    end
  end

  describe "#download_event_xml" do
    it "returns binary event XML bytes" do
      transport.enqueue(json(body: "<evento/>"))
      xml = resource.download_event_xml(company_id: "co-1", access_key: access_key, event_key: "ev-9")

      expect(xml).to start_with("<")
      expect(last_request.url)
        .to eq("https://api.nfse.io/v2/companies/co-1/inbound/#{access_key}/events/ev-9/xml")
      expect(last_request.headers["Accept"]).to eq("application/xml")
    end
  end
end
