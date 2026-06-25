# frozen_string_literal: true

require "json"
require "nfe/resources/service_invoices_rtc"

RSpec.describe Nfe::Resources::ServiceInvoicesRtc do
  # The +service_invoices_rtc+ client accessor is wired by the orchestrator
  # after this slice, so the resource is instantiated directly here.
  subject(:resource) { described_class.new(client) }

  let(:client) { Nfe::Client.new(api_key: "key") }
  let(:transport) { FakeTransport.new }
  # An RTC payload: the +ibsCbs+ group is what selects the RTC layout on the
  # shared +/serviceinvoices+ endpoint (no discriminator header/param).
  let(:rtc_payload) do
    {
      "borrower" => { "name" => "ACME Ltda", "federalTaxNumber" => 11_222_333_000_181 },
      "cityServiceCode" => "0107",
      "description" => "Consultoria",
      "servicesAmount" => 1000.0,
      "ibsCbs" => {
        "operationIndicator" => "1005011",
        "classCode" => "000001",
        "basis" => 1000.0,
        "cbs" => { "rate" => 0.009, "amount" => 9.0 },
        "ibs" => { "rate" => 0.001, "amount" => 1.0 },
        "operationType" => "SupplyForPastPay"
      }
    }
  end

  before { allow(client).to receive(:build_transport).and_return(transport) }

  def response(status: 200, body: "{}", headers: {})
    Nfe::Http::Response.new(status: status, headers: headers, body: body)
  end

  def last_request
    transport.requests.last
  end

  describe "#create" do
    it "returns a ServiceInvoiceRtcPending on 202, parsing invoice_id from Location" do
      location = "/v1/companies/co_1/serviceinvoices/inv-rtc-1"
      transport.enqueue(response(status: 202, headers: { "location" => location }, body: ""))

      result = resource.create(company_id: "co_1", data: rtc_payload)

      expect(result).to be_a(Nfe::Resources::ServiceInvoiceRtcPending)
      expect(result.pending?).to be(true)
      expect(result.issued?).to be(false)
      expect(result.invoice_id).to eq("inv-rtc-1")
      expect(result.location).to eq(location)
      expect(last_request.method).to eq("POST")
      expect(last_request.url).to start_with("https://api.nfe.io/v1/companies/co_1/serviceinvoices")
      expect(last_request.headers["Content-Type"]).to eq("application/json")
    end

    it "returns a ServiceInvoiceRtcIssued on 201, hydrating a Nfe::ServiceInvoice" do
      transport.enqueue(response(status: 201, body: { "id" => "si_rtc_1", "flowStatus" => "Issued" }.to_json))

      result = resource.create(company_id: "co_1", data: rtc_payload)

      expect(result).to be_a(Nfe::Resources::ServiceInvoiceRtcIssued)
      expect(result.issued?).to be(true)
      expect(result.pending?).to be(false)
      expect(result.resource).to be_a(Nfe::ServiceInvoice)
      expect(result.resource.id).to eq("si_rtc_1")
      expect(result.resource.flow_status).to eq("Issued")
    end

    it "raises InvoiceProcessingError on a 202 without Location" do
      transport.enqueue(response(status: 202, body: ""))
      expect { resource.create(company_id: "co_1", data: rtc_payload) }
        .to raise_error(Nfe::InvoiceProcessingError)
    end

    it "carries the ibsCbs group through to the JSON request body" do
      transport.enqueue(response(status: 201, body: { "id" => "si_rtc_1" }.to_json))
      resource.create(company_id: "co_1", data: rtc_payload)

      parsed = JSON.parse(last_request.body)
      expect(parsed).to include("ibsCbs")
      expect(parsed["ibsCbs"]).to include("operationIndicator" => "1005011", "classCode" => "000001")
      expect(parsed["ibsCbs"]).to include("cbs" => { "rate" => 0.009, "amount" => 9.0 })
      expect(parsed["servicesAmount"]).to eq(1000.0)
    end

    it "forwards idempotency_key on the request when present" do
      transport.enqueue(response(status: 201, body: { "id" => "si_rtc_1" }.to_json))
      resource.create(company_id: "co_1", data: rtc_payload, idempotency_key: "order-rtc-42")
      expect(last_request.idempotency_key).to eq("order-rtc-42")
    end

    it "omits the idempotency_key when absent" do
      transport.enqueue(response(status: 201, body: { "id" => "si_rtc_1" }.to_json))
      resource.create(company_id: "co_1", data: rtc_payload)
      expect(last_request.idempotency_key).to be_nil
    end

    it "applies per-call request_options without mutating the client" do
      transport.enqueue(response(status: 201, body: { "id" => "si_rtc_1" }.to_json))
      opts = Nfe::RequestOptions.new(api_key: "tenant-key")
      resource.create(company_id: "co_1", data: rtc_payload, request_options: opts)
      expect(last_request.headers["X-NFE-APIKEY"]).to eq("tenant-key")

      transport.enqueue(response(status: 201, body: { "id" => "si_rtc_2" }.to_json))
      resource.create(company_id: "co_1", data: rtc_payload)
      expect(last_request.headers["X-NFE-APIKEY"]).to eq("key")
    end

    it "rejects an empty company_id before issuing any HTTP request" do
      expect { resource.create(company_id: "  ", data: rtc_payload) }
        .to raise_error(Nfe::InvalidRequestError)
      expect(transport.requests).to be_empty
    end
  end

  describe "#retrieve" do
    it "hydrates a Nfe::ServiceInvoice" do
      transport.enqueue(response(body: { "id" => "si_rtc_1", "flowStatus" => "Issued" }.to_json))
      invoice = resource.retrieve(company_id: "co_1", invoice_id: "si_rtc_1")

      expect(invoice).to be_a(Nfe::ServiceInvoice)
      expect(invoice.id).to eq("si_rtc_1")
      expect(last_request.method).to eq("GET")
      expect(last_request.url).to eq("https://api.nfe.io/v1/companies/co_1/serviceinvoices/si_rtc_1")
    end

    it "raises NotFoundError on 404" do
      transport.enqueue(response(status: 404, body: "{}"))
      expect { resource.retrieve(company_id: "co_1", invoice_id: "missing") }
        .to raise_error(Nfe::NotFoundError)
    end

    it "rejects an empty invoice_id before issuing any HTTP request" do
      expect { resource.retrieve(company_id: "co_1", invoice_id: "") }
        .to raise_error(Nfe::InvalidRequestError)
      expect(transport.requests).to be_empty
    end
  end

  describe "#cancel" do
    it "DELETEs and returns the updated invoice" do
      transport.enqueue(response(body: { "id" => "si_rtc_1", "flowStatus" => "Cancelled" }.to_json))
      invoice = resource.cancel(company_id: "co_1", invoice_id: "si_rtc_1")

      expect(last_request.method).to eq("DELETE")
      expect(last_request.url).to eq("https://api.nfe.io/v1/companies/co_1/serviceinvoices/si_rtc_1")
      expect(invoice).to be_a(Nfe::ServiceInvoice)
      expect(invoice.flow_status).to eq("Cancelled")
    end
  end

  describe "#download_cancellation_xml" do
    it "returns ASCII-8BIT bytes starting with < and an xml Accept header" do
      transport.enqueue(response(body: "<CancNFSe/>".b))
      xml = resource.download_cancellation_xml(company_id: "co_1", invoice_id: "si_rtc_1")

      expect(xml.encoding).to eq(Encoding::ASCII_8BIT)
      expect(xml).to start_with("<")
      expect(last_request.method).to eq("GET")
      expect(last_request.headers["Accept"]).to eq("application/xml")
      expect(last_request.url).to end_with("/serviceinvoices/si_rtc_1/cancellation-xml")
    end

    it "raises NotFoundError when the body is empty" do
      transport.enqueue(response(status: 404, body: ""))
      expect { resource.download_cancellation_xml(company_id: "co_1", invoice_id: "missing") }
        .to raise_error(Nfe::NotFoundError)
    end

    it "rejects an empty invoice_id before issuing any HTTP request" do
      expect { resource.download_cancellation_xml(company_id: "co_1", invoice_id: " ") }
        .to raise_error(Nfe::InvalidRequestError)
      expect(transport.requests).to be_empty
    end
  end

  describe "routing" do
    it "targets the api.nfe.io host for the :main family" do
      transport.enqueue(response(body: { "id" => "si_rtc_1" }.to_json))
      resource.retrieve(company_id: "co_1", invoice_id: "si_rtc_1")
      expect(last_request.url).to start_with("https://api.nfe.io")
    end
  end
end
