# frozen_string_literal: true

require "date"

RSpec.describe Nfe::DateNormalizer do
  describe ".to_iso_date" do
    it "passes a well-formed ISO date string through unchanged" do
      expect(described_class.to_iso_date("2026-01-15")).to eq("2026-01-15")
    end

    it "formats a Date as YYYY-MM-DD" do
      expect(described_class.to_iso_date(Date.new(1990, 1, 15))).to eq("1990-01-15")
    end

    it "formats a Time, discarding the time component" do
      expect(described_class.to_iso_date(Time.new(2026, 6, 24, 13, 45, 0))).to eq("2026-06-24")
    end

    it "formats a DateTime, discarding the time component" do
      expect(described_class.to_iso_date(DateTime.new(2026, 6, 24, 13, 45, 0))).to eq("2026-06-24")
    end

    it "raises on a non-ISO format such as DD/MM/YYYY" do
      expect { described_class.to_iso_date("15/01/1990") }
        .to raise_error(Nfe::InvalidRequestError, /YYYY-MM-DD/)
    end

    it "raises on an out-of-range ISO date" do
      expect { described_class.to_iso_date("2026-13-45") }
        .to raise_error(Nfe::InvalidRequestError, /intervalo|inválida/)
    end

    it "raises on an unexpected type" do
      expect { described_class.to_iso_date(20_260_115) }
        .to raise_error(Nfe::InvalidRequestError, /tipo/)
    end
  end
end
