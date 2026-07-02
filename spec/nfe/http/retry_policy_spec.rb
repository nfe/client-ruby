# frozen_string_literal: true

RSpec.describe Nfe::Http::RetryPolicy do
  describe ".default" do
    subject(:policy) { described_class.default }

    it "uses the recommended settings" do
      expect(policy.max_retries).to eq(3)
      expect(policy.base_delay).to eq(1.0)
      expect(policy.max_delay).to eq(30.0)
      expect(policy.jitter).to eq(0.3)
    end
  end

  describe ".none" do
    subject(:policy) { described_class.none }

    it "disables retries with zero delay" do
      expect(policy.max_retries).to eq(0)
      expect(policy.delay_for(1)).to eq(0.0)
    end
  end

  describe "#delay_for" do
    it "caps the delay at max_delay even for large attempts" do
      policy = described_class.new(max_retries: 10, base_delay: 1.0, max_delay: 5.0, jitter: 0.0)

      100.times do
        expect(policy.delay_for(20)).to be <= 5.0
      end
    end

    it "keeps jittered values within [base*(1-j), base*(1+j)]" do
      policy = described_class.new(max_retries: 3, base_delay: 2.0, max_delay: 100.0, jitter: 0.3)
      base = 2.0 * (2**(2 - 1)) # attempt 2 => 4.0

      500.times do
        delay = policy.delay_for(2)
        expect(delay).to be >= (base * 0.7) - 1e-9
        expect(delay).to be <= (base * 1.3) + 1e-9
      end
    end

    it "grows exponentially with the attempt index" do
      policy = described_class.new(max_retries: 5, base_delay: 1.0, max_delay: 1000.0, jitter: 0.0)

      expect(policy.delay_for(1)).to be_within(1e-9).of(1.0)
      expect(policy.delay_for(2)).to be_within(1e-9).of(2.0)
      expect(policy.delay_for(3)).to be_within(1e-9).of(4.0)
    end

    it "clamps jittered values to max_delay" do
      policy = described_class.new(max_retries: 5, base_delay: 30.0, max_delay: 30.0, jitter: 0.3)

      200.times do
        expect(policy.delay_for(3)).to be <= 30.0
      end
    end
  end
end
