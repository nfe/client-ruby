# frozen_string_literal: true

require "json"

RSpec.describe Nfe::Resources::ProductInvoices do
  subject(:invoices) { client.product_invoices }

  let(:client) { Nfe::Client.new(api_key: "key") }
  let(:transport) { FakeTransport.new }

  before { allow(client).to receive(:build_transport).and_return(transport) }

  def json(status: 200, body: "{}", headers: {})
    Nfe::Http::Response.new(status: status, headers: headers, body: body)
  end

  def last_request
    transport.requests.last
  end

  describe "host routing" do
    it "targets https://api.nfse.io/v2 (distinct from the main host)" do
      transport.enqueue(json(status: 201, body: { "id" => "pi_1" }.to_json))
      invoices.create(company_id: "co_1", data: {})
      expect(last_request.url).to start_with("https://api.nfse.io/v2/companies/co_1/productinvoices")
    end
  end

  describe "#create" do
    it "returns a ProductInvoicePending on 202" do
      location = "/v2/companies/co_1/productinvoices/pi-async-1"
      transport.enqueue(json(status: 202, headers: { "location" => location }, body: ""))

      result = invoices.create(company_id: "co_1", data: {})

      expect(result).to be_a(Nfe::Resources::ProductInvoicePending)
      expect(result.invoice_id).to eq("pi-async-1")
      expect(last_request.method).to eq("POST")
    end

    it "returns a ProductInvoiceIssued on 201" do
      transport.enqueue(json(status: 201, body: { "id" => "pi_1", "flowStatus" => "Issued" }.to_json))
      result = invoices.create(company_id: "co_1", data: {})
      expect(result).to be_a(Nfe::Resources::ProductInvoiceIssued)
      expect(result.resource.id).to eq("pi_1")
    end

    it "forwards idempotency_key and per-call request_options" do
      transport.enqueue(json(status: 201, body: { "id" => "pi_1" }.to_json))
      invoices.create(company_id: "co_1", data: {}, idempotency_key: "k-1",
                      request_options: Nfe::RequestOptions.new(api_key: "tenant"))
      expect(last_request.idempotency_key).to eq("k-1")
      expect(last_request.headers["X-NFE-APIKEY"]).to eq("tenant")
    end
  end

  describe "#create_with_state_tax" do
    it "routes through the statetaxes path and validates state_tax_id" do
      transport.enqueue(json(status: 202, headers: {
                               "location" => "/v2/companies/co_1/productinvoices/pi_2"
                             }, body: ""))
      invoices.create_with_state_tax(company_id: "co_1", state_tax_id: "st_1", data: {})
      expect(last_request.url).to include("/companies/co_1/statetaxes/st_1/productinvoices")
    end

    it "rejects an empty state_tax_id before HTTP" do
      expect { invoices.create_with_state_tax(company_id: "co_1", state_tax_id: " ", data: {}) }
        .to raise_error(Nfe::InvalidRequestError)
      expect(transport.requests).to be_empty
    end
  end

  describe "#list" do
    it "returns a cursor-style ListResponse and sends environment" do
      transport.enqueue(json(body: {
        "productInvoices" => [{ "id" => "a" }], "startingAfter" => "a"
      }.to_json))

      result = invoices.list(company_id: "co_1", environment: "Production", limit: 50)

      expect(result).to be_a(Nfe::ListResponse)
      expect(result.data.map(&:id)).to eq(["a"])
      expect(result.page.starting_after).to eq("a")
      expect(result.page.page_index).to be_nil
      expect(last_request.url).to include("environment=Production").and include("limit=50")
    end

    it "rejects a missing environment before HTTP" do
      expect { invoices.list(company_id: "co_1", environment: nil) }
        .to raise_error(Nfe::InvalidRequestError)
      expect(transport.requests).to be_empty
    end
  end

  describe "#cancel" do
    it "DELETEs with the reason in the query and returns the resource" do
      transport.enqueue(json(body: { "id" => "cancel_1" }.to_json))
      result = invoices.cancel(company_id: "co_1", invoice_id: "pi_1", reason: "Erro")
      expect(last_request.method).to eq("DELETE")
      expect(last_request.url).to include("reason=Erro")
      expect(result["id"]).to eq("cancel_1")
    end
  end

  describe "#list_items and #list_events" do
    it "lists items via the cursor sub-path" do
      transport.enqueue(json(body: { "items" => [{ "id" => "it_1" }] }.to_json))
      result = invoices.list_items(company_id: "co_1", invoice_id: "pi_1", limit: 10)
      expect(result).to be_a(Nfe::ListResponse)
      expect(last_request.url).to include("/productinvoices/pi_1/items").and include("limit=10")
    end

    it "lists events via the cursor sub-path" do
      transport.enqueue(json(body: { "events" => [{ "id" => "ev_1" }] }.to_json))
      invoices.list_events(company_id: "co_1", invoice_id: "pi_1")
      expect(last_request.url).to include("/productinvoices/pi_1/events")
    end
  end

  describe "downloads return a file URI (NfeFileResource)" do
    it "download_pdf returns a NfeFileResource and forwards force" do
      transport.enqueue(json(body: { "uri" => "https://files/abc.pdf" }.to_json))
      file = invoices.download_pdf(company_id: "co_1", invoice_id: "pi_1", force: true)
      expect(file).to be_a(Nfe::NfeFileResource)
      expect(file.uri).to eq("https://files/abc.pdf")
      expect(last_request.url).to include("/pdf").and include("force=true")
    end

    it "download_xml/rejection/epec hit the right paths and return URIs" do
      %w[xml xml-rejection xml-epec].each do |segment|
        transport.enqueue(json(body: { "uri" => "https://files/#{segment}" }.to_json))
      end
      expect(invoices.download_xml(company_id: "co_1", invoice_id: "pi_1")).to be_a(Nfe::NfeFileResource)
      expect(last_request.url).to end_with("/pi_1/xml")
      invoices.download_rejection_xml(company_id: "co_1", invoice_id: "pi_1")
      expect(last_request.url).to end_with("/pi_1/xml-rejection")
      invoices.download_epec_xml(company_id: "co_1", invoice_id: "pi_1")
      expect(last_request.url).to end_with("/pi_1/xml-epec")
    end
  end

  describe "#send_correction_letter" do
    it "PUTs the reason when length is in range" do
      transport.enqueue(json(body: { "id" => "cc_1" }.to_json))
      invoices.send_correction_letter(company_id: "co_1", invoice_id: "pi_1",
                                      reason: "Correção válida com tamanho suficiente")
      expect(last_request.method).to eq("PUT")
      expect(last_request.url).to end_with("/pi_1/correctionletter")
      expect(JSON.parse(last_request.body)["reason"]).to start_with("Correção")
    end

    it "rejects a too-short reason before HTTP" do
      expect { invoices.send_correction_letter(company_id: "co_1", invoice_id: "pi_1", reason: "curto") }
        .to raise_error(Nfe::InvalidRequestError)
      expect(transport.requests).to be_empty
    end

    it "rejects a too-long reason before HTTP" do
      expect { invoices.send_correction_letter(company_id: "co_1", invoice_id: "pi_1", reason: "a" * 1001) }
        .to raise_error(Nfe::InvalidRequestError)
      expect(transport.requests).to be_empty
    end
  end

  describe "correction letter downloads" do
    it "return NfeFileResource URIs" do
      transport.enqueue(json(body: { "uri" => "https://files/cc.pdf" }.to_json))
      file = invoices.download_correction_letter_pdf(company_id: "co_1", invoice_id: "pi_1")
      expect(file).to be_a(Nfe::NfeFileResource)
      expect(last_request.url).to end_with("/correctionletter/pdf")
      transport.enqueue(json(body: { "uri" => "https://files/cc.xml" }.to_json))
      invoices.download_correction_letter_xml(company_id: "co_1", invoice_id: "pi_1")
      expect(last_request.url).to end_with("/correctionletter/xml")
    end
  end

  describe "#disable and #disable_range" do
    it "POSTs disablement for a single invoice with the reason in query" do
      transport.enqueue(json(body: { "id" => "dis_1" }.to_json))
      invoices.disable(company_id: "co_1", invoice_id: "pi_1", reason: "Erro")
      expect(last_request.method).to eq("POST")
      expect(last_request.url).to include("/pi_1/disablement").and include("reason=Erro")
    end

    it "POSTs a range disablement with the body" do
      transport.enqueue(json(body: { "id" => "dis_2" }.to_json))
      data = { environment: "Production", serie: 1, state: "SP", begin_number: 10, last_number: 20 }
      invoices.disable_range(company_id: "co_1", data: data)
      expect(last_request.url).to end_with("/productinvoices/disablement")
      expect(JSON.parse(last_request.body)["serie"]).to eq(1)
    end
  end
end
