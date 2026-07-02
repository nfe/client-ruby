# frozen_string_literal: true

require "json"

RSpec.describe Nfe::Resources::ConsumerInvoices do
  subject(:consumer_invoices) { client.consumer_invoices }

  let(:client) { Nfe::Client.new(api_key: "key") }
  let(:transport) { FakeTransport.new }

  before { allow(client).to receive(:build_transport).and_return(transport) }

  def response(status: 200, body: "{}", headers: {})
    Nfe::Http::Response.new(status: status, headers: headers, body: body)
  end

  def last_request
    transport.requests.last
  end

  describe "routing" do
    it "targets the api.nfse.io /v2 host for every call" do
      transport.enqueue(response(body: { "consumerInvoices" => [] }.to_json))
      consumer_invoices.list(company_id: "co", environment: "Test")
      expect(last_request.url).to start_with("https://api.nfse.io/v2/companies/co/consumerinvoices")
    end

    it "declares the :cte api_family" do
      expect(consumer_invoices.send(:api_family)).to eq(:cte)
    end
  end

  describe "#create" do
    context "when the API enqueues the NFC-e (HTTP 202)" do
      before do
        transport.enqueue(response(
                            status: 202,
                            headers: { "location" => "/v2/companies/co/consumerinvoices/nfc-77" }
                          ))
      end

      it "returns a ConsumerInvoicePending discriminating as pending" do
        result = consumer_invoices.create(company_id: "co", data: { totalAmount: 10 })

        expect(result).to be_a(Nfe::Resources::ConsumerInvoicePending)
        expect(result).to be_pending
        expect(result).not_to be_issued
        expect(result.invoice_id).to eq("nfc-77")
        expect(result.location).to eq("/v2/companies/co/consumerinvoices/nfc-77")
      end

      it "POSTs a JSON body with the proper Content-Type" do
        consumer_invoices.create(company_id: "co", data: { totalAmount: 10 })

        expect(last_request.method).to eq("POST")
        expect(last_request.headers["Content-Type"]).to eq("application/json")
        expect(JSON.parse(last_request.body)).to eq({ "totalAmount" => 10 })
      end

      it "forwards idempotency_key on the request" do
        consumer_invoices.create(company_id: "co", data: {}, idempotency_key: "order-42")
        expect(last_request.idempotency_key).to eq("order-42")
      end

      it "threads per-call request_options without mutating the client" do
        consumer_invoices.create(
          company_id: "co", data: {},
          request_options: Nfe::RequestOptions.new(api_key: "tenant-key")
        )
        expect(last_request.headers["X-NFE-APIKEY"]).to eq("tenant-key")
      end
    end

    context "when the API materializes the NFC-e (HTTP 201)" do
      before do
        transport.enqueue(response(
                            status: 201,
                            body: { "id" => "nfc-1", "flowStatus" => "Issued", "accessKey" => "k" }.to_json
                          ))
      end

      it "returns a ConsumerInvoiceIssued wrapping a hydrated model" do
        result = consumer_invoices.create(company_id: "co", data: {})

        expect(result).to be_a(Nfe::Resources::ConsumerInvoiceIssued)
        expect(result).to be_issued
        expect(result).not_to be_pending
        expect(result.resource).to be_a(Nfe::ConsumerInvoice)
        expect(result.resource.id).to eq("nfc-1")
        expect(result.resource.flow_status).to eq("Issued")
      end
    end

    context "when 202 arrives without a Location header" do
      before { transport.enqueue(response(status: 202)) }

      it "raises InvoiceProcessingError" do
        expect { consumer_invoices.create(company_id: "co", data: {}) }
          .to raise_error(Nfe::InvoiceProcessingError)
      end
    end

    it "rejects an empty company_id before any HTTP request" do
      expect { consumer_invoices.create(company_id: "  ", data: {}) }
        .to raise_error(Nfe::InvalidRequestError)
      expect(transport.requests).to be_empty
    end
  end

  describe "#create_with_state_tax" do
    before do
      transport.enqueue(response(
                          status: 202,
                          headers: { "location" => "/v2/companies/co/consumerinvoices/nfc-9" }
                        ))
    end

    it "routes to the state-tax-scoped path and returns a Pending" do
      result = consumer_invoices.create_with_state_tax(
        company_id: "co", state_tax_id: "st-1", data: {}, idempotency_key: "k1"
      )

      expect(result).to be_a(Nfe::Resources::ConsumerInvoicePending)
      expect(last_request.url)
        .to start_with("https://api.nfse.io/v2/companies/co/statetaxes/st-1/consumerinvoices")
      expect(last_request.idempotency_key).to eq("k1")
    end

    it "validates the state_tax_id before HTTP" do
      expect { consumer_invoices.create_with_state_tax(company_id: "co", state_tax_id: "", data: {}) }
        .to raise_error(Nfe::InvalidRequestError)
      expect(transport.requests).to be_empty
    end
  end

  describe "#list" do
    before do
      transport.enqueue(response(body: {
        "consumerInvoices" => [{ "id" => "a" }, { "id" => "b" }],
        "startingAfter" => "a", "endingBefore" => "b"
      }.to_json))
    end

    it "returns a cursor-style ListResponse of hydrated models" do
      result = consumer_invoices.list(company_id: "co", environment: "Test", limit: 50, starting_after: "x")

      expect(result).to be_a(Nfe::ListResponse)
      expect(result.data.map(&:id)).to eq(%w[a b])
      expect(result.data.first).to be_a(Nfe::ConsumerInvoice)
      expect(result.page.starting_after).to eq("a")
      expect(result.page.page_index).to be_nil
      expect(last_request.url).to include("limit=50").and include("starting_after=x").and include("environment=Test")
    end

    it "iterates via Enumerable" do
      result = consumer_invoices.list(company_id: "co", environment: "Test")
      expect(result.map(&:id)).to eq(%w[a b])
    end

    it "exige environment não-vazio antes de qualquer HTTP" do
      expect { consumer_invoices.list(company_id: "co", environment: " ") }
        .to raise_error(Nfe::InvalidRequestError)
      expect(transport.requests).to be_empty
    end
  end

  describe "#retrieve" do
    it "hydrates a ConsumerInvoice" do
      transport.enqueue(response(body: { "id" => "nfc-1", "status" => "Issued" }.to_json))
      invoice = consumer_invoices.retrieve(company_id: "co", invoice_id: "nfc-1")

      expect(invoice).to be_a(Nfe::ConsumerInvoice)
      expect(invoice.id).to eq("nfc-1")
      expect(last_request.url).to eq("https://api.nfse.io/v2/companies/co/consumerinvoices/nfc-1")
    end

    it "rejects an empty invoice_id before HTTP" do
      expect { consumer_invoices.retrieve(company_id: "co", invoice_id: " ") }
        .to raise_error(Nfe::InvalidRequestError)
      expect(transport.requests).to be_empty
    end
  end

  describe "#cancel" do
    it "DELETEs synchronously and returns the updated model" do
      transport.enqueue(response(body: { "id" => "nfc-1", "status" => "Cancelled" }.to_json))
      invoice = consumer_invoices.cancel(company_id: "co", invoice_id: "nfc-1")

      expect(invoice.status).to eq("Cancelled")
      expect(last_request.method).to eq("DELETE")
      expect(last_request.url).to eq("https://api.nfse.io/v2/companies/co/consumerinvoices/nfc-1")
    end
  end

  describe "#list_items" do
    it "returns the unwrapped items array" do
      transport.enqueue(response(body: { "items" => [{ "code" => "x" }] }.to_json))
      items = consumer_invoices.list_items(company_id: "co", invoice_id: "nfc-1")

      expect(items).to eq([{ "code" => "x" }])
      expect(last_request.url).to end_with("/consumerinvoices/nfc-1/items")
    end

    it "tolerates a bare array body" do
      transport.enqueue(response(body: [{ "code" => "y" }].to_json))
      expect(consumer_invoices.list_items(company_id: "co", invoice_id: "nfc-1"))
        .to eq([{ "code" => "y" }])
    end
  end

  describe "#list_events" do
    it "returns the unwrapped events array" do
      transport.enqueue(response(body: { "events" => [{ "type" => "Cancel" }] }.to_json))
      events = consumer_invoices.list_events(company_id: "co", invoice_id: "nfc-1")

      expect(events).to eq([{ "type" => "Cancel" }])
      expect(last_request.url).to end_with("/consumerinvoices/nfc-1/events")
    end
  end

  describe "byte downloads" do
    it "#download_pdf returns ASCII-8BIT PDF bytes with an Accept header" do
      transport.enqueue(response(body: "%PDF-1.4 binary".b))
      bytes = consumer_invoices.download_pdf(company_id: "co", invoice_id: "nfc-1")

      expect(bytes.encoding).to eq(Encoding::ASCII_8BIT)
      expect(bytes[0, 4]).to eq("%PDF")
      expect(last_request.headers["Accept"]).to eq("application/pdf")
      expect(last_request.url).to end_with("/consumerinvoices/nfc-1/pdf")
    end

    it "#download_xml returns ASCII-8BIT XML bytes" do
      transport.enqueue(response(body: "<nfeProc>".b))
      bytes = consumer_invoices.download_xml(company_id: "co", invoice_id: "nfc-1")

      expect(bytes.encoding).to eq(Encoding::ASCII_8BIT)
      expect(bytes[0]).to eq("<")
      expect(last_request.headers["Accept"]).to eq("application/xml")
    end

    it "#download_rejection_xml hits the rejection path and returns bytes" do
      transport.enqueue(response(body: "<rejection/>".b))
      bytes = consumer_invoices.download_rejection_xml(company_id: "co", invoice_id: "nfc-1")

      expect(bytes.encoding).to eq(Encoding::ASCII_8BIT)
      expect(last_request.url).to end_with("/consumerinvoices/nfc-1/xml/rejection")
    end
  end

  describe "#disable_range" do
    it "POSTs the collective inutilization payload" do
      transport.enqueue(response(body: { "status" => "Done" }.to_json))
      result = consumer_invoices.disable_range(
        company_id: "co",
        data: { environment: "Production", serie: 1, state: "SP", begin_number: 1, last_number: 10 }
      )

      expect(result).to eq({ "status" => "Done" })
      expect(last_request.method).to eq("POST")
      expect(last_request.url).to end_with("/consumerinvoices/disablement")
      expect(last_request.headers["Content-Type"]).to eq("application/json")
    end
  end

  describe "methods absent by fiscal law" do
    it "does not define send_correction_letter (CC-e is NF-e only)" do
      expect { consumer_invoices.send_correction_letter }.to raise_error(NoMethodError)
    end

    it "does not define download_epec_xml (no EPEC for NFC-e)" do
      expect { consumer_invoices.download_epec_xml }.to raise_error(NoMethodError)
    end

    it "does not define a per-invoice disable (only disable_range)" do
      expect { consumer_invoices.disable }.to raise_error(NoMethodError)
    end
  end
end
