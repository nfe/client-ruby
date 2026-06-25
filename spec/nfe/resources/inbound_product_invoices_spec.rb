# frozen_string_literal: true

require "json"

RSpec.describe Nfe::Resources::InboundProductInvoices do
  subject(:resource) { client.inbound_product_invoices }

  let(:client) { Nfe::Client.new(api_key: "key", data_api_key: "data-key") }
  let(:transport) { FakeTransport.new }
  let(:access_key) { "5" * 44 }

  before { allow(client).to receive(:build_transport).and_return(transport) }

  def json(status: 200, body: "{}", headers: {})
    Nfe::Http::Response.new(status: status, headers: headers, body: body)
  end

  def last_request
    transport.requests.last
  end

  describe "#enable_auto_fetch" do
    before { transport.enqueue(json(body: { "status" => "Active" }.to_json)) }

    it "POSTs to api.nfse.io and returns hydrated settings" do
      settings = resource.enable_auto_fetch(
        company_id: "co-1", start_from_nsu: "99", environment_sefaz: "Production", webhook_version: "2"
      )

      expect(settings).to be_a(Nfe::InboundSettings)
      expect(last_request.method).to eq("POST")
      expect(last_request.url).to eq("https://api.nfse.io/v2/companies/co-1/inbound/productinvoices")
      body = JSON.parse(last_request.body)
      expect(body).to eq(
        { "startFromNsu" => "99", "environmentSEFAZ" => "Production", "webhookVersion" => "2" }
      )
    end

    it "rejects an empty company_id without HTTP" do
      expect { resource.enable_auto_fetch(company_id: "") }.to raise_error(Nfe::InvalidRequestError)
      expect(transport.requests).to be_empty
    end
  end

  describe "#disable_auto_fetch" do
    it "DELETEs the productinvoices settings" do
      transport.enqueue(json(body: { "status" => "Disabled" }.to_json))
      resource.disable_auto_fetch(company_id: "co-1")

      expect(last_request.method).to eq("DELETE")
      expect(last_request.url).to eq("https://api.nfse.io/v2/companies/co-1/inbound/productinvoices")
    end
  end

  describe "#get_settings" do
    it "GETs the productinvoices settings" do
      transport.enqueue(json(body: { "status" => "Active" }.to_json))
      resource.get_settings(company_id: "co-1")

      expect(last_request.method).to eq("GET")
      expect(last_request.url).to eq("https://api.nfse.io/v2/companies/co-1/inbound/productinvoices")
    end
  end

  describe "detail endpoints" do
    it "#get_details uses the webhook-v1 path" do
      transport.enqueue(json(body: { "accessKey" => access_key }.to_json))
      doc = resource.get_details(company_id: "co-1", access_key: access_key)

      expect(doc).to be_a(Nfe::InboundInvoiceMetadata)
      expect(last_request.url).to eq("https://api.nfse.io/v2/companies/co-1/inbound/#{access_key}")
    end

    it "#get_product_invoice_details uses the webhook-v2 path" do
      transport.enqueue(json(body: { "accessKey" => access_key, "productInvoices" => [{ "id" => "p1" }] }.to_json))
      doc = resource.get_product_invoice_details(company_id: "co-1", access_key: access_key)

      expect(doc.product_invoices).to eq([{ "id" => "p1" }])
      expect(last_request.url)
        .to eq("https://api.nfse.io/v2/companies/co-1/inbound/productinvoice/#{access_key}")
    end

    it "normalises a formatted access key" do
      transport.enqueue(json(body: "{}"))
      resource.get_details(company_id: "co-1", access_key: access_key.scan(/.{4}/).join("."))
      expect(last_request.url).to eq("https://api.nfse.io/v2/companies/co-1/inbound/#{access_key}")
    end
  end

  describe "event endpoints" do
    it "#get_event_details uses the v1 events path" do
      transport.enqueue(json(body: "{}"))
      resource.get_event_details(company_id: "co-1", access_key: access_key, event_key: "ev-1")
      expect(last_request.url)
        .to eq("https://api.nfse.io/v2/companies/co-1/inbound/#{access_key}/events/ev-1")
    end

    it "#get_product_invoice_event_details uses the v2 events path" do
      transport.enqueue(json(body: "{}"))
      resource.get_product_invoice_event_details(company_id: "co-1", access_key: access_key, event_key: "ev-1")
      expect(last_request.url)
        .to eq("https://api.nfse.io/v2/companies/co-1/inbound/productinvoice/#{access_key}/events/ev-1")
    end

    it "rejects an empty event_key without HTTP" do
      expect { resource.get_event_details(company_id: "co-1", access_key: access_key, event_key: " ") }
        .to raise_error(Nfe::InvalidRequestError)
      expect(transport.requests).to be_empty
    end
  end

  describe "downloads" do
    it "#get_xml returns binary XML bytes" do
      transport.enqueue(json(body: "<nfeProc/>"))
      xml = resource.get_xml(company_id: "co-1", access_key: access_key)

      expect(xml).to start_with("<")
      expect(xml.encoding).to eq(Encoding::ASCII_8BIT)
      expect(last_request.url).to eq("https://api.nfse.io/v2/companies/co-1/inbound/#{access_key}/xml")
      expect(last_request.headers["Accept"]).to eq("application/xml")
    end

    it "#get_event_xml returns binary event XML bytes" do
      transport.enqueue(json(body: "<evento/>"))
      resource.get_event_xml(company_id: "co-1", access_key: access_key, event_key: "ev-1")
      expect(last_request.url)
        .to eq("https://api.nfse.io/v2/companies/co-1/inbound/#{access_key}/events/ev-1/xml")
    end

    it "#get_pdf returns binary PDF bytes with a PDF Accept header" do
      transport.enqueue(json(body: "%PDF-1.7 bytes"))
      pdf = resource.get_pdf(company_id: "co-1", access_key: access_key)

      expect(pdf[0, 4]).to eq("%PDF")
      expect(pdf.encoding).to eq(Encoding::ASCII_8BIT)
      expect(last_request.url).to eq("https://api.nfse.io/v2/companies/co-1/inbound/#{access_key}/pdf")
      expect(last_request.headers["Accept"]).to eq("application/pdf")
    end
  end

  describe "#get_json" do
    it "GETs the structured JSON and hydrates it" do
      transport.enqueue(json(body: { "nameSender" => "Fornecedor" }.to_json))
      doc = resource.get_json(company_id: "co-1", access_key: access_key)

      expect(doc).to be_a(Nfe::InboundInvoiceMetadata)
      expect(doc.name_sender).to eq("Fornecedor")
      expect(last_request.url)
        .to eq("https://api.nfse.io/v2/companies/co-1/inbound/productinvoice/#{access_key}/json")
    end
  end

  describe "#manifest" do
    it "defaults tpEvent to 210210 (awareness)" do
      transport.enqueue(json(body: "ok"))
      result = resource.manifest(company_id: "co-1", access_key: access_key)

      expect(result).to eq("ok")
      expect(last_request.method).to eq("POST")
      expect(last_request.url)
        .to eq("https://api.nfse.io/v2/companies/co-1/inbound/#{access_key}/manifest?tpEvent=210210")
    end

    it "forwards an explicit tpEvent" do
      transport.enqueue(json(body: "ok"))
      resource.manifest(company_id: "co-1", access_key: access_key,
                        tp_event: described_class::MANIFEST_CONFIRMATION)
      expect(last_request.url).to include("tpEvent=210220")
    end

    it "exposes symbolic manifest constants" do
      expect(described_class::MANIFEST_AWARENESS).to eq(210_210)
      expect(described_class::MANIFEST_CONFIRMATION).to eq(210_220)
      expect(described_class::MANIFEST_NOT_PERFORMED).to eq(210_240)
    end
  end

  describe "#reprocess_webhook" do
    it "accepts a 44-digit access key" do
      transport.enqueue(json(body: "{}"))
      resource.reprocess_webhook(company_id: "co-1", access_key_or_nsu: access_key)
      expect(last_request.method).to eq("POST")
      expect(last_request.url)
        .to eq("https://api.nfse.io/v2/companies/co-1/inbound/productinvoice/#{access_key}/processwebhook")
    end

    it "accepts a numeric NSU without rejecting it as an invalid key" do
      transport.enqueue(json(body: "{}"))
      expect { resource.reprocess_webhook(company_id: "co-1", access_key_or_nsu: 12_345) }
        .not_to raise_error
      expect(last_request.url)
        .to eq("https://api.nfse.io/v2/companies/co-1/inbound/productinvoice/12345/processwebhook")
    end

    it "rejects an empty identifier without HTTP" do
      expect { resource.reprocess_webhook(company_id: "co-1", access_key_or_nsu: "") }
        .to raise_error(Nfe::InvalidRequestError)
      expect(transport.requests).to be_empty
    end
  end
end
