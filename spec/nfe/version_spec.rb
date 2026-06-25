# frozen_string_literal: true

RSpec.describe Nfe do
  it "pins the major version at 1.0.0" do
    expect(Nfe::VERSION).to eq("1.0.0")
  end
end
