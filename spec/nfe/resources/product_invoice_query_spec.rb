# frozen_string_literal: true

require "json"

RSpec.describe Nfe::Resources::ProductInvoiceQuery do
  subject(:product_invoice_query) { client.product_invoice_query }

  let(:client) { Nfe::Client.new(api_key: "key", data_api_key: "datakey") }
  let(:transport) { FakeTransport.new }
  let(:access_key) { "1" * 44 }

  # Real GET /v2/productinvoices/{accessKey} response shape: the status field is
  # "currentStatus" (lowercase enum), there is NO top-level "accessKey", and the
  # totals live under the nested "icms" group.
  let(:payload) do
    {
      "currentStatus" => "authorized",
      "stateCode" => 35,
      "checkCode" => 12_345_678,
      "serie" => 1,
      "number" => 42,
      "issuedOn" => "2026-01-01T00:00:00Z",
      "issuer" => {
        "federalTaxNumber" => 11_222_333_000_181,
        "name" => "Emitente LTDA",
        "tradeName" => "Emitente",
        "stateTaxNumber" => "123456789"
      },
      "buyer" => { "federalTaxNumber" => 98_765_432_000_199, "name" => "Destinatario SA" },
      "totals" => { "icms" => { "productAmount" => 150.0, "invoiceAmount" => 150.0 } }
    }
  end

  before { allow(client).to receive(:build_transport).and_return(transport) }

  def response(status: 200, body: "{}", headers: {})
    Nfe::Http::Response.new(status: status, headers: headers, body: body)
  end

  def last_request = transport.requests.last

  describe "#retrieve" do
    it "targets the nfe query host" do
      transport.enqueue(response(body: { "accessKey" => access_key }.to_json))
      product_invoice_query.retrieve(access_key)
      expect(last_request.url).to start_with("https://nfe.api.nfe.io")
    end

    it "normalizes an access key with spaces and dots to 44 digits in the path" do
      # 44 ones interleaved with spaces and dots; the resource strips them all.
      spaced = ("1" * 44).chars.each_slice(4).map(&:join).join(" .")
      transport.enqueue(response(body: "{}"))
      product_invoice_query.retrieve(spaced)
      expect(last_request.url).to include("/v2/productinvoices/#{access_key}")
    end

    it "hydrates the invoice details with the real top-level keys" do
      transport.enqueue(response(body: payload.to_json))

      result = product_invoice_query.retrieve(access_key)

      expect(result).to be_a(Nfe::ProductInvoiceDetails)
      expect(result.current_status).to eq("authorized")
      expect(result.number).to eq(42)
      expect(result.serie).to eq(1)
      expect(result.issued_on).to eq("2026-01-01T00:00:00Z")
      expect(result.state_code).to eq(35)
    end

    it "hydrates the nested issuer, buyer and totals" do
      transport.enqueue(response(body: payload.to_json))

      result = product_invoice_query.retrieve(access_key)

      expect(result.issuer.name).to eq("Emitente LTDA")
      expect(result.issuer.federal_tax_number).to eq("11222333000181")
      expect(result.buyer.name).to eq("Destinatario SA")
      expect(result.totals.invoice_amount).to eq(150.0)
    end

    it "rejects a malformed access key before HTTP" do
      expect { product_invoice_query.retrieve("123") }
        .to raise_error(Nfe::InvalidRequestError)
      expect(transport.requests).to be_empty
    end
  end

  describe "#download_pdf" do
    it "sends Accept application/pdf and returns the bytes" do
      transport.enqueue(response(body: "%PDF-1.4 binary"))
      bytes = product_invoice_query.download_pdf(access_key)

      expect(bytes).to start_with("%PDF")
      expect(last_request.headers["Accept"]).to eq("application/pdf")
      expect(last_request.url).to end_with("/v2/productinvoices/#{access_key}.pdf")
    end
  end

  describe "#download_xml" do
    it "sends Accept application/xml and uses the .xml suffix" do
      transport.enqueue(response(body: "<nfeProc/>"))
      bytes = product_invoice_query.download_xml(access_key)

      expect(bytes).to start_with("<nfeProc")
      expect(last_request.headers["Accept"]).to eq("application/xml")
      expect(last_request.url).to end_with("/v2/productinvoices/#{access_key}.xml")
    end
  end

  describe "#list_events" do
    it "hits the events sub-path and hydrates the events response" do
      transport.enqueue(response(body: {
        "events" => [{ "type" => "Cancellation" }],
        "createdOn" => "2026-01-01T00:00:00Z"
      }.to_json))

      result = product_invoice_query.list_events(access_key)

      expect(result).to be_a(Nfe::ProductInvoiceEventsResponse)
      expect(result.events.length).to eq(1)
      expect(last_request.url).to include("/v2/productinvoices/events/#{access_key}")
    end
  end
end
