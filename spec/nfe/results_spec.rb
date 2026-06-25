# frozen_string_literal: true

RSpec.describe Nfe::Pending do
  it "exposes invoice_id and location" do
    pending = described_class.new(invoice_id: "abc-123", location: "/v1/companies/x/serviceinvoices/abc-123")

    expect(pending.invoice_id).to eq("abc-123")
    expect(pending.location).to eq("/v1/companies/x/serviceinvoices/abc-123")
  end

  it "compares by value" do
    a = described_class.new(invoice_id: "abc", location: "/loc")
    b = described_class.new(invoice_id: "abc", location: "/loc")

    expect(a).to eq(b)
  end

  it "is frozen and immutable" do
    expect(described_class.new(invoice_id: "abc", location: "/loc")).to be_frozen
  end

  it "is distinguishable from Nfe::Issued via is_a?" do
    result = described_class.new(invoice_id: "abc", location: "/loc")

    expect(result).to be_a(described_class)
    expect(result).not_to be_a(Nfe::Issued)
  end

  describe Nfe::Issued do
    it "exposes resource" do
      dto = Object.new
      issued = described_class.new(resource: dto)

      expect(issued.resource).to be(dto)
    end

    it "compares by value" do
      one = described_class.new(resource: "r")
      two = described_class.new(resource: "r")
      expect(one).to eq(two)
    end

    it "is distinguishable from Nfe::Pending via is_a?" do
      result = described_class.new(resource: "r")

      expect(result).to be_a(described_class)
      expect(result).not_to be_a(Nfe::Pending)
    end
  end
end
