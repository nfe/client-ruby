# frozen_string_literal: true

RSpec.describe "invoice discriminated response value objects" do # rubocop:disable RSpec/DescribeClass
  describe Nfe::Resources::ServiceInvoicePending do
    subject(:pending) { described_class.new(invoice_id: "inv_1", location: "/v1/.../inv_1") }

    it "answers pending? true and issued? false" do
      expect(pending.pending?).to be(true)
      expect(pending.issued?).to be(false)
    end

    it "exposes invoice_id and location" do
      expect(pending.invoice_id).to eq("inv_1")
      expect(pending.location).to eq("/v1/.../inv_1")
    end

    it "is immutable and pattern-matches by type" do
      branch =
        case pending
        in Nfe::Resources::ServiceInvoicePending then :pending # rubocop:disable RSpec/DescribedClass
        else :other
        end
      expect(branch).to eq(:pending)
      expect(pending).to be_frozen
    end
  end

  describe Nfe::Resources::ServiceInvoiceIssued do
    subject(:issued) { described_class.new(resource: :invoice) }

    it "answers issued? true and pending? false" do
      expect(issued.issued?).to be(true)
      expect(issued.pending?).to be(false)
    end

    it "exposes the hydrated resource" do
      expect(issued.resource).to eq(:invoice)
    end
  end

  describe Nfe::Resources::ProductInvoicePending do
    subject(:pending) { described_class.new(invoice_id: "p_1", location: "loc") }

    it "answers pending? true and issued? false" do
      expect(pending.pending?).to be(true)
      expect(pending.issued?).to be(false)
    end
  end

  describe Nfe::Resources::ProductInvoiceIssued do
    subject(:issued) { described_class.new(resource: :p) }

    it "answers issued? true and pending? false" do
      expect(issued.issued?).to be(true)
      expect(issued.pending?).to be(false)
    end
  end
end
