# frozen_string_literal: true

require "json"
require "nfe/resources/product_invoices_rtc"

RSpec.describe Nfe::Resources::ProductInvoicesRtc do
  # The +product_invoices_rtc+ client accessor is wired by the orchestrator
  # after this slice, so the resource is instantiated directly here.
  subject(:resource) { described_class.new(client) }

  let(:client) { Nfe::Client.new(api_key: "key") }
  let(:transport) { FakeTransport.new }
  # An RTC product payload: the item-level +tax.IBSCBS+ group is what selects
  # the RTC layout on the shared +/productinvoices+ endpoint (no discriminator
  # header/param). NF-e (mod 55) vs NFC-e (mod 65) follows the payload shape.
  let(:rtc_payload) do
    {
      "buyer" => { "name" => "ACME Ltda", "federalTaxNumber" => "11222333000181" },
      "operationNature" => "Venda",
      "serie" => 1,
      "items" => [
        {
          "code" => "P-1",
          "description" => "Produto RTC",
          "ncm" => "85171231",
          "quantity" => 1,
          "unitAmount" => 100.0,
          "totalAmount" => 100.0,
          "tax" => {
            "IBSCBS" => {
              "situationCode" => "000",
              "classCode" => "000001",
              "calculationMode" => "OfficialService"
            }
          }
        }
      ]
    }
  end

  before { allow(client).to receive(:build_transport).and_return(transport) }

  def response(status: 200, body: "{}", headers: {})
    Nfe::Http::Response.new(status: status, headers: headers, body: body)
  end

  def last_request
    transport.requests.last
  end

  describe "host routing" do
    it "targets https://api.nfse.io/v2 (distinct from the main host)" do
      transport.enqueue(response(status: 201, body: { "id" => "pi_1" }.to_json))
      resource.create(company_id: "co_1", data: rtc_payload)
      expect(last_request.url).to start_with("https://api.nfse.io/v2/companies/co_1/productinvoices")
    end
  end

  describe "#create" do
    it "returns a ProductInvoiceRtcPending on 202, parsing invoice_id from Location" do
      location = "/v2/companies/co_1/productinvoices/pi-rtc-async-1"
      transport.enqueue(response(status: 202, headers: { "location" => location }, body: ""))

      result = resource.create(company_id: "co_1", data: rtc_payload)

      expect(result).to be_a(Nfe::Resources::ProductInvoiceRtcPending)
      expect(result.pending?).to be(true)
      expect(result.issued?).to be(false)
      expect(result.invoice_id).to eq("pi-rtc-async-1")
      expect(result.location).to eq(location)
      expect(last_request.method).to eq("POST")
      expect(last_request.headers["Content-Type"]).to eq("application/json")
    end

    it "returns a ProductInvoiceRtcIssued on 201, hydrating an InvoiceResource" do
      transport.enqueue(response(status: 201, body: { "id" => "pi_rtc_1", "status" => "Issued" }.to_json))

      result = resource.create(company_id: "co_1", data: rtc_payload)

      expect(result).to be_a(Nfe::Resources::ProductInvoiceRtcIssued)
      expect(result.issued?).to be(true)
      expect(result.resource).to be_a(Nfe::Generated::ProductInvoiceRtcV1::InvoiceResource)
      expect(result.resource.id).to eq("pi_rtc_1")
    end

    it "raises InvoiceProcessingError on a 202 with no Location header" do
      transport.enqueue(response(status: 202, body: ""))
      expect { resource.create(company_id: "co_1", data: rtc_payload) }
        .to raise_error(Nfe::InvoiceProcessingError)
    end

    it "serializes the camelCase payload, carrying items[].tax.IBSCBS" do
      transport.enqueue(response(status: 201, body: { "id" => "pi_1" }.to_json))
      resource.create(company_id: "co_1", data: rtc_payload)

      body = JSON.parse(last_request.body)
      ibscbs = body.dig("items", 0, "tax", "IBSCBS")
      expect(ibscbs["situationCode"]).to eq("000")
      expect(ibscbs["classCode"]).to eq("000001")
    end

    it "forwards idempotency_key and per-call request_options" do
      transport.enqueue(response(status: 201, body: { "id" => "pi_1" }.to_json))
      resource.create(company_id: "co_1", data: rtc_payload, idempotency_key: "k-1",
                      request_options: Nfe::RequestOptions.new(api_key: "tenant"))
      expect(last_request.idempotency_key).to eq("k-1")
      expect(last_request.headers["X-NFE-APIKEY"]).to eq("tenant")
    end

    it "rejects an empty company_id before any HTTP call" do
      expect { resource.create(company_id: " ", data: rtc_payload) }
        .to raise_error(Nfe::InvalidRequestError)
      expect(transport.requests).to be_empty
    end
  end

  describe "#create_with_state_tax" do
    it "routes through the statetaxes path" do
      transport.enqueue(response(status: 202, headers: {
                                   "location" => "/v2/companies/co_1/productinvoices/pi_2"
                                 }, body: ""))
      resource.create_with_state_tax(company_id: "co_1", state_tax_id: "st_1", data: rtc_payload)
      expect(last_request.url).to include("/companies/co_1/statetaxes/st_1/productinvoices")
    end

    it "rejects an empty state_tax_id before any HTTP call" do
      expect { resource.create_with_state_tax(company_id: "co_1", state_tax_id: " ", data: rtc_payload) }
        .to raise_error(Nfe::InvalidRequestError)
      expect(transport.requests).to be_empty
    end
  end

  describe "#retrieve" do
    it "GETs the invoice and hydrates an InvoiceResource" do
      transport.enqueue(response(body: { "id" => "pi_1", "number" => 42 }.to_json))
      result = resource.retrieve(company_id: "co_1", invoice_id: "pi_1")
      expect(result).to be_a(Nfe::Generated::ProductInvoiceRtcV1::InvoiceResource)
      expect(result.id).to eq("pi_1")
      expect(last_request.url).to end_with("/productinvoices/pi_1")
    end

    it "raises NotFoundError on 404" do
      transport.enqueue(response(status: 404, body: "{}"))
      expect { resource.retrieve(company_id: "co_1", invoice_id: "missing") }
        .to raise_error(Nfe::NotFoundError)
    end
  end

  describe "#list" do
    it "returns a cursor-style ListResponse and sends environment" do
      transport.enqueue(response(body: {
        "productInvoices" => [{ "id" => "a" }], "startingAfter" => "a"
      }.to_json))

      result = resource.list(company_id: "co_1", environment: "Production", limit: 50)

      expect(result).to be_a(Nfe::ListResponse)
      expect(result.data.first).to be_a(Nfe::Generated::ProductInvoiceRtcV1::InvoiceResource)
      expect(result.data.map(&:id)).to eq(["a"])
      expect(result.page.starting_after).to eq("a")
      expect(result.page.page_index).to be_nil
      expect(last_request.url).to include("environment=Production").and include("limit=50")
    end

    it "rejects a missing environment before any HTTP call" do
      expect { resource.list(company_id: "co_1", environment: nil) }
        .to raise_error(Nfe::InvalidRequestError)
      expect(transport.requests).to be_empty
    end
  end

  describe "#cancel" do
    it "DELETEs with the reason in the query and hydrates a RequestCancellationResource" do
      transport.enqueue(response(body: { "reason" => "Erro", "productInvoiceId" => "pi_1" }.to_json))
      result = resource.cancel(company_id: "co_1", invoice_id: "pi_1", reason: "Erro")
      expect(last_request.method).to eq("DELETE")
      expect(last_request.url).to include("reason=Erro")
      expect(result).to be_a(Nfe::Generated::ProductInvoiceRtcV1::RequestCancellationResource)
      expect(result.product_invoice_id).to eq("pi_1")
    end
  end

  describe "#list_items and #list_events" do
    it "lists items and hydrates an InvoiceItemsResource" do
      transport.enqueue(response(body: { "id" => "pi_1", "items" => [{ "code" => "it_1" }] }.to_json))
      result = resource.list_items(company_id: "co_1", invoice_id: "pi_1")
      expect(result).to be_a(Nfe::Generated::ProductInvoiceRtcV1::InvoiceItemsResource)
      expect(last_request.url).to end_with("/productinvoices/pi_1/items")
    end

    it "lists events and hydrates an InvoiceEventsResource" do
      transport.enqueue(response(body: { "id" => "pi_1", "events" => [{ "id" => "ev_1" }] }.to_json))
      result = resource.list_events(company_id: "co_1", invoice_id: "pi_1")
      expect(result).to be_a(Nfe::Generated::ProductInvoiceRtcV1::InvoiceEventsResource)
      expect(last_request.url).to end_with("/productinvoices/pi_1/events")
    end
  end

  describe "downloads return a file URI (NfeFileResource)" do
    it "download_pdf returns a NfeFileResource and forwards force" do
      transport.enqueue(response(body: { "uri" => "https://files/abc.pdf" }.to_json))
      file = resource.download_pdf(company_id: "co_1", invoice_id: "pi_1", force: true)
      expect(file).to be_a(Nfe::NfeFileResource)
      expect(file.uri).to eq("https://files/abc.pdf")
      expect(last_request.url).to include("/pdf").and include("force=true")
    end

    it "download_xml/rejection/epec hit the right paths and return URIs" do
      transport.enqueue(response(body: { "uri" => "https://files/xml" }.to_json))
      expect(resource.download_xml(company_id: "co_1", invoice_id: "pi_1")).to be_a(Nfe::NfeFileResource)
      expect(last_request.url).to end_with("/pi_1/xml")

      transport.enqueue(response(body: { "uri" => "https://files/rej" }.to_json))
      resource.download_rejection_xml(company_id: "co_1", invoice_id: "pi_1")
      expect(last_request.url).to end_with("/pi_1/xml-rejection")

      transport.enqueue(response(body: { "uri" => "https://files/epec" }.to_json))
      resource.download_epec_xml(company_id: "co_1", invoice_id: "pi_1")
      expect(last_request.url).to end_with("/pi_1/xml-epec")
    end
  end

  describe "#send_correction_letter" do
    it "PUTs the reason when length is in range and hydrates the resource" do
      transport.enqueue(response(body: { "reason" => "Correção", "productInvoiceId" => "pi_1" }.to_json))
      result = resource.send_correction_letter(company_id: "co_1", invoice_id: "pi_1",
                                               reason: "Correção válida com tamanho suficiente")
      expect(last_request.method).to eq("PUT")
      expect(last_request.url).to end_with("/pi_1/correctionletter")
      expect(JSON.parse(last_request.body)["reason"]).to start_with("Correção")
      expect(result).to be_a(Nfe::Generated::ProductInvoiceRtcV1::RequestCancellationResource)
    end

    it "rejects a too-short reason before any HTTP call" do
      expect { resource.send_correction_letter(company_id: "co_1", invoice_id: "pi_1", reason: "curto") }
        .to raise_error(Nfe::InvalidRequestError)
      expect(transport.requests).to be_empty
    end

    it "rejects a too-long reason before any HTTP call" do
      expect { resource.send_correction_letter(company_id: "co_1", invoice_id: "pi_1", reason: "a" * 1001) }
        .to raise_error(Nfe::InvalidRequestError)
      expect(transport.requests).to be_empty
    end
  end

  describe "correction letter downloads" do
    it "return NfeFileResource URIs" do
      transport.enqueue(response(body: { "uri" => "https://files/cc.pdf" }.to_json))
      file = resource.download_correction_letter_pdf(company_id: "co_1", invoice_id: "pi_1")
      expect(file).to be_a(Nfe::NfeFileResource)
      expect(last_request.url).to end_with("/correctionletter/pdf")

      transport.enqueue(response(body: { "uri" => "https://files/cc.xml" }.to_json))
      resource.download_correction_letter_xml(company_id: "co_1", invoice_id: "pi_1")
      expect(last_request.url).to end_with("/correctionletter/xml")
    end
  end

  describe "#disable and #disable_range" do
    it "POSTs disablement for a single invoice with the reason in query" do
      transport.enqueue(response(body: { "reason" => "Erro", "serie" => 1 }.to_json))
      result = resource.disable(company_id: "co_1", invoice_id: "pi_1", reason: "Erro")
      expect(last_request.method).to eq("POST")
      expect(last_request.url).to include("/pi_1/disablement").and include("reason=Erro")
      expect(result).to be_a(Nfe::Generated::ProductInvoiceRtcV1::DisablementResource)
    end

    it "POSTs a range disablement with the body" do
      transport.enqueue(response(body: { "serie" => 1, "beginNumber" => 10, "lastNumber" => 20 }.to_json))
      data = { "environment" => "Production", "serie" => 1, "state" => "SP",
               "beginNumber" => 10, "lastNumber" => 20 }
      result = resource.disable_range(company_id: "co_1", data: data)
      expect(last_request.url).to end_with("/productinvoices/disablement")
      expect(JSON.parse(last_request.body)["serie"]).to eq(1)
      expect(result).to be_a(Nfe::Generated::ProductInvoiceRtcV1::DisablementResource)
      expect(result.begin_number).to eq(10)
    end
  end

  describe "fail-fast id validation" do
    it "rejects an empty invoice_id on retrieve before any HTTP call" do
      expect { resource.retrieve(company_id: "co_1", invoice_id: " ") }
        .to raise_error(Nfe::InvalidRequestError)
      expect(transport.requests).to be_empty
    end

    it "rejects an empty company_id on download_pdf before any HTTP call" do
      expect { resource.download_pdf(company_id: " ", invoice_id: "pi_1") }
        .to raise_error(Nfe::InvalidRequestError)
      expect(transport.requests).to be_empty
    end
  end
end
