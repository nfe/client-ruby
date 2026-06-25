# frozen_string_literal: true

RSpec.describe "NFC-e discriminated response value objects" do # rubocop:disable RSpec/DescribeClass
  describe Nfe::Resources::ConsumerInvoicePending do
    subject(:pending) { described_class.new(invoice_id: "nfc-1", location: "/v2/.../nfc-1") }

    it "discriminates as pending" do
      expect(pending).to be_pending
      expect(pending).not_to be_issued
    end

    it "exposes invoice_id and location" do
      expect(pending.invoice_id).to eq("nfc-1")
      expect(pending.location).to eq("/v2/.../nfc-1")
    end

    it "matches via Data pattern matching" do
      result = pending
      matched =
        case result
        in Nfe::Resources::ConsumerInvoicePending then :pending # rubocop:disable RSpec/DescribedClass
        in Nfe::Resources::ConsumerInvoiceIssued then :issued
        end
      expect(matched).to eq(:pending)
    end

    it "is an immutable value object" do
      expect(pending).to be_frozen
    end
  end

  describe Nfe::Resources::ConsumerInvoiceIssued do
    subject(:issued) { described_class.new(resource: invoice) }

    let(:invoice) { Nfe::ConsumerInvoice.from_api("id" => "nfc-2") }

    it "discriminates as issued" do
      expect(issued).to be_issued
      expect(issued).not_to be_pending
    end

    it "exposes the hydrated resource" do
      expect(issued.resource).to be(invoice)
      expect(issued.resource.id).to eq("nfc-2")
    end

    it "matches via Data pattern matching" do
      matched =
        case issued
        in Nfe::Resources::ConsumerInvoicePending then :pending
        in Nfe::Resources::ConsumerInvoiceIssued then :issued # rubocop:disable RSpec/DescribedClass
        end
      expect(matched).to eq(:issued)
    end
  end
end
