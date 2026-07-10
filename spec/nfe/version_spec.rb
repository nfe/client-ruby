# frozen_string_literal: true

RSpec.describe Nfe do
  it "pins the gem version" do
    expect(Nfe::VERSION).to eq("1.1.0")
  end
end
