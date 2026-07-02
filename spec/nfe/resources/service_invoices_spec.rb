# frozen_string_literal: true

require "json"

RSpec.describe Nfe::Resources::ServiceInvoices do
  subject(:invoices) { client.service_invoices }

  let(:client) { Nfe::Client.new(api_key: "key") }
  let(:transport) { FakeTransport.new }

  before { allow(client).to receive(:build_transport).and_return(transport) }

  def json(status: 200, body: "{}", headers: {})
    Nfe::Http::Response.new(status: status, headers: headers, body: body)
  end

  def last_request
    transport.requests.last
  end

  describe "#create" do
    it "returns a ServiceInvoicePending on 202, parsing invoice_id from Location" do
      location = "/v1/companies/co_1/serviceinvoices/inv-abc-1"
      transport.enqueue(json(status: 202, headers: { "location" => location }, body: ""))

      result = invoices.create(company_id: "co_1", data: { description: "x" })

      expect(result).to be_a(Nfe::Resources::ServiceInvoicePending)
      expect(result.pending?).to be(true)
      expect(result.invoice_id).to eq("inv-abc-1")
      expect(result.location).to eq(location)
      expect(last_request.method).to eq("POST")
      expect(last_request.url).to start_with("https://api.nfe.io/v1/companies/co_1/serviceinvoices")
      expect(last_request.headers["Content-Type"]).to eq("application/json")
    end

    it "returns a ServiceInvoiceIssued on 201, hydrating the body" do
      transport.enqueue(json(status: 201, body: { "id" => "si_1", "flowStatus" => "Issued" }.to_json))

      result = invoices.create(company_id: "co_1", data: {})

      expect(result).to be_a(Nfe::Resources::ServiceInvoiceIssued)
      expect(result.issued?).to be(true)
      expect(result.resource).to be_a(Nfe::ServiceInvoice)
      expect(result.resource.id).to eq("si_1")
    end

    it "raises InvoiceProcessingError on a 202 without Location" do
      transport.enqueue(json(status: 202, body: ""))
      expect { invoices.create(company_id: "co_1", data: {}) }
        .to raise_error(Nfe::InvoiceProcessingError)
    end

    it "forwards idempotency_key on the request" do
      transport.enqueue(json(status: 201, body: { "id" => "si_1" }.to_json))
      invoices.create(company_id: "co_1", data: {}, idempotency_key: "order-42")
      expect(last_request.idempotency_key).to eq("order-42")
    end

    it "applies per-call request_options without mutating the client" do
      transport.enqueue(json(status: 201, body: { "id" => "si_1" }.to_json))
      opts = Nfe::RequestOptions.new(api_key: "tenant-key")
      invoices.create(company_id: "co_1", data: {}, request_options: opts)

      expect(last_request.headers["X-NFE-APIKEY"]).to eq("tenant-key")
      transport.enqueue(json(status: 201, body: { "id" => "si_2" }.to_json))
      invoices.create(company_id: "co_1", data: {})
      expect(last_request.headers["X-NFE-APIKEY"]).to eq("key")
    end

    it "rejects an empty company_id before HTTP" do
      expect { invoices.create(company_id: "  ", data: {}) }
        .to raise_error(Nfe::InvalidRequestError)
      expect(transport.requests).to be_empty
    end
  end

  describe "#list" do
    it "returns a page-style ListResponse with date filters" do
      transport.enqueue(json(body: {
        "serviceInvoices" => [{ "id" => "a" }, { "id" => "b" }],
        "pageIndex" => 0, "pageCount" => 20
      }.to_json))

      result = invoices.list(company_id: "co_1", page_index: 0, page_count: 20,
                             issued_begin: "2026-01-01", issued_end: "2026-01-31")

      expect(result).to be_a(Nfe::ListResponse)
      expect(result.data.map(&:id)).to eq(%w[a b])
      expect(result.page.page_index).to eq(0)
      expect(result.page.starting_after).to be_nil
      expect(last_request.url).to include("issuedBegin=2026-01-01").and include("pageCount=20")
    end
  end

  describe "#retrieve" do
    it "hydrates a ServiceInvoice" do
      transport.enqueue(json(body: { "id" => "si_1", "flowStatus" => "Issued" }.to_json))
      invoice = invoices.retrieve(company_id: "co_1", invoice_id: "si_1")
      expect(invoice).to be_a(Nfe::ServiceInvoice)
      expect(invoice.id).to eq("si_1")
      expect(last_request.url).to eq("https://api.nfe.io/v1/companies/co_1/serviceinvoices/si_1")
    end

    it "raises NotFoundError on 404" do
      transport.enqueue(json(status: 404, body: "{}"))
      expect { invoices.retrieve(company_id: "co_1", invoice_id: "missing") }
        .to raise_error(Nfe::NotFoundError)
    end
  end

  describe "#cancel" do
    it "DELETEs and returns the updated invoice" do
      transport.enqueue(json(body: { "id" => "si_1", "flowStatus" => "Cancelled" }.to_json))
      invoice = invoices.cancel(company_id: "co_1", invoice_id: "si_1")
      expect(last_request.method).to eq("DELETE")
      expect(invoice.flow_status).to eq("Cancelled")
    end
  end

  describe "#send_email" do
    it "PUTs to /sendemail and returns the send result" do
      transport.enqueue(json(body: { "sent" => true, "message" => "ok" }.to_json))
      result = invoices.send_email(company_id: "co_1", invoice_id: "si_1")
      expect(last_request.method).to eq("PUT")
      expect(last_request.url).to end_with("/serviceinvoices/si_1/sendemail")
      expect(result[:sent]).to be(true)
      expect(result[:message]).to eq("ok")
    end
  end

  describe "#download_pdf" do
    it "returns ASCII-8BIT bytes starting with %PDF" do
      transport.enqueue(json(body: "%PDF-1.4 binary".b))
      pdf = invoices.download_pdf(company_id: "co_1", invoice_id: "si_1")
      expect(pdf.encoding).to eq(Encoding::ASCII_8BIT)
      expect(pdf).to start_with("%PDF")
      expect(last_request.headers["Accept"]).to eq("application/pdf")
      expect(last_request.url).to end_with("/serviceinvoices/si_1/pdf")
    end

    it "targets the bulk path when invoice_id is omitted" do
      transport.enqueue(json(body: "PK\x03\x04zip".b))
      invoices.download_pdf(company_id: "co_1")
      expect(last_request.url).to end_with("/serviceinvoices/pdf")
    end
  end

  describe "#download_xml" do
    it "returns bytes starting with < and the xml Accept header" do
      transport.enqueue(json(body: "<nfse/>".b))
      xml = invoices.download_xml(company_id: "co_1", invoice_id: "si_1")
      expect(xml).to start_with("<")
      expect(last_request.headers["Accept"]).to eq("application/xml")
    end
  end

  describe "#get_status" do
    it "derives status from retrieve without an extra HTTP call" do
      transport.enqueue(json(body: { "id" => "si_1", "flowStatus" => "Issued" }.to_json))
      status = invoices.get_status(company_id: "co_1", invoice_id: "si_1")

      expect(status.status).to eq("Issued")
      expect(status.complete?).to be(true)
      expect(status.failed?).to be(false)
      expect(status.invoice).to be_a(Nfe::ServiceInvoice)
      expect(transport.requests.length).to eq(1)
    end

    it "flags failed for IssueFailed" do
      transport.enqueue(json(body: { "id" => "si_1", "flowStatus" => "IssueFailed" }.to_json))
      status = invoices.get_status(company_id: "co_1", invoice_id: "si_1")
      expect(status.complete?).to be(true)
      expect(status.failed?).to be(true)
    end
  end
end
