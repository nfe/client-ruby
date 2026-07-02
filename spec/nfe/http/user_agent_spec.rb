# frozen_string_literal: true

RSpec.describe Nfe::Http::UserAgent do
  describe ".build" do
    it "uses the canonical format with version, ruby version and platform" do
      expect(described_class.build).to eq(
        "NFE.io Ruby Client v#{Nfe::VERSION} ruby/#{RUBY_VERSION} (#{RUBY_PLATFORM})"
      )
    end

    it "matches the documented shape" do
      expect(described_class.build).to match(
        %r{\ANFE\.io Ruby Client v\S+ ruby/\S+ \(.+\)\z}
      )
    end

    it "appends a non-empty suffix after a single space" do
      expect(described_class.build("MyApp/2.0")).to eq(
        "NFE.io Ruby Client v#{Nfe::VERSION} ruby/#{RUBY_VERSION} (#{RUBY_PLATFORM}) MyApp/2.0"
      )
    end

    it "ignores a nil or empty suffix" do
      expect(described_class.build(nil)).to eq(described_class.build)
      expect(described_class.build("")).to eq(described_class.build)
    end
  end
end
