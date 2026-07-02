# frozen_string_literal: true

RSpec.describe Nfe::FlowStatus do
  describe ".terminal?" do
    it "is true for settled states" do
      %w[Issued IssueFailed Cancelled CancelFailed].each do |status|
        expect(described_class.terminal?(status)).to be(true)
      end
    end

    it "is false for in-progress states" do
      %w[PullFromCityHall WaitingCalculateTaxes WaitingSend WaitingReturn].each do |status|
        expect(described_class.terminal?(status)).to be(false)
      end
    end

    it "coerces non-string input before matching" do
      expect(described_class.terminal?(:Issued)).to be(true)
      expect(described_class.terminal?(nil)).to be(false)
    end
  end

  it "exposes every status through ALL" do
    expect(described_class::ALL).to match_array(described_class::TERMINAL + described_class::NON_TERMINAL)
  end
end
