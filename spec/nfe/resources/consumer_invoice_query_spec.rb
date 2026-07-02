# frozen_string_literal: true

require "json"

RSpec.describe Nfe::Resources::ConsumerInvoiceQuery do
  subject(:consumer_invoice_query) { client.consumer_invoice_query }

  let(:client) { Nfe::Client.new(api_key: "key", data_api_key: "datakey") }
  let(:transport) { FakeTransport.new }
  # Canonical 44-digit NFC-e access key, and the same key supplied with
  # formatting separators to prove IdValidator normalizes it back to 44 digits.
  let(:normalized_key) { "3" * 44 }
  let(:formatted_key) { "3333 3333.3333/3333-3333 3333 3333 3333 3333 3333 3333" }

  before { allow(client).to receive(:build_transport).and_return(transport) }

  def response(status: 200, body: "{}", headers: {})
    Nfe::Http::Response.new(status: status, headers: headers, body: body)
  end

  def last_request = transport.requests.last

  describe "routing" do
    it "declares the :nfe_query api_family with an empty version" do
      expect(consumer_invoice_query.send(:api_family)).to eq(:nfe_query)
      expect(consumer_invoice_query.send(:api_version)).to eq("")
    end
  end

  describe "#retrieve" do
    # Realistic CFe-SAT coupon body using the REAL camelCase keys and enum
    # values from the TaxCouponResource schema (totals{totalAmount,couponAmount},
    # payment{payBack,paymentDetails:[{method,amount}]}, items:[{netAmount,
    # grossAmount}], delivery{address}). A mismapped DTO leaves these members nil
    # and fails the hydration assertions below.
    let(:payload) do
      {
        "currentStatus" => "Authorized",
        "number" => 10,
        "satSerie" => "900001234",
        "accessKey" => normalized_key,
        "issuer" => { "federalTaxNumber" => 12_345_678_000_199, "name" => "Loja XPTO",
                      "tradeName" => "XPTO", "stateTaxNumber" => 123_456_789 },
        "buyer" => { "federalTaxNumber" => 11_122_233_396, "name" => "Consumidor" },
        "totals" => { "totalAmount" => 4.9, "couponAmount" => 49.9 },
        "delivery" => { "address" => { "street" => "Rua A", "number" => "100",
                                       "district" => "Centro", "postalCode" => 1_310_100 } },
        "additionalInformation" => { "taxpayer" => "Obrigado pela preferência" },
        "items" => [{ "code" => 1, "description" => "Café", "cfop" => 5102,
                      "netAmount" => 49.9, "grossAmount" => 49.9 }],
        "payment" => { "payBack" => 0.1,
                       "paymentDetails" => [{ "method" => "Cash", "amount" => 50.0 }] }
      }
    end

    before { transport.enqueue(response(body: payload.to_json)) }

    it "hits the nfe.api.nfe.io v1 coupon path with the normalized 44-digit key" do
      consumer_invoice_query.retrieve(formatted_key)

      expect(last_request.method).to eq("GET")
      expect(last_request.url).to start_with("https://nfe.api.nfe.io")
      expect(last_request.url).to end_with("/v1/consumerinvoices/coupon/#{normalized_key}")
    end

    it "hydrates the TaxCoupon scalars and issuer/buyer" do
      coupon = consumer_invoice_query.retrieve(formatted_key)

      expect(coupon).to be_a(Nfe::TaxCoupon)
      expect(coupon.current_status).to eq("Authorized")
      expect(coupon.access_key).to eq(normalized_key)
      expect(coupon.issuer).to be_a(Nfe::TaxCoupon::Issuer)
      expect(coupon.issuer.name).to eq("Loja XPTO")
      expect(coupon.issuer.federal_tax_number).to eq("12345678000199")
      expect(coupon.buyer.federal_tax_number).to eq("11122233396")
    end

    it "hydrates totals, items, payment and delivery with the real keys" do
      coupon = consumer_invoice_query.retrieve(formatted_key)

      expect(coupon.totals.total_amount).to eq(4.9)
      expect(coupon.totals.coupon_amount).to eq(49.9)
      expect(coupon.items.first).to be_a(Nfe::TaxCoupon::Item)
      expect(coupon.items.first.net_amount).to eq(49.9)
      expect(coupon.items.first.gross_amount).to eq(49.9)
      expect(coupon.payment.pay_back).to eq(0.1)
      expect(coupon.payment.payment_details.first.method).to eq("Cash")
      expect(coupon.payment.payment_details.first.amount).to eq(50.0)
      expect(coupon.delivery.address.district).to eq("Centro")
    end

    it "rejects an access key that is not 44 digits before any HTTP request" do
      transport_with_no_calls = FakeTransport.new
      allow(client).to receive(:build_transport).and_return(transport_with_no_calls)

      expect { consumer_invoice_query.retrieve("123") }.to raise_error(Nfe::InvalidRequestError)
      expect(transport_with_no_calls.requests).to be_empty
    end
  end

  describe "#download_xml" do
    before { transport.enqueue(response(body: "<nfeProc>...</nfeProc>".b)) }

    it "uses the .xml suffix, an XML Accept header, and returns binary bytes" do
      bytes = consumer_invoice_query.download_xml(formatted_key)

      expect(bytes).to be_a(String)
      expect(bytes.encoding).to eq(Encoding::ASCII_8BIT)
      expect(bytes).to start_with("<nfeProc>")
      expect(last_request.headers["Accept"]).to eq("application/xml")
      expect(last_request.url).to end_with("/v1/consumerinvoices/coupon/#{normalized_key}.xml")
      expect(last_request.url).to start_with("https://nfe.api.nfe.io")
    end
  end
end
