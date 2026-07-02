# frozen_string_literal: true

# Behavior of per-call Nfe::RequestOptions threaded through Nfe::Client#request
# (the value object itself is covered in request_options_spec.rb).
RSpec.describe "Nfe::Client per-call request options" do # rubocop:disable RSpec/DescribeClass
  subject(:client) { Nfe::Client.new(api_key: "client-key") }

  def with_fake_transport(target)
    fake = FakeTransport.new([Nfe::Http::Response.new(status: 200, body: "{}")])
    allow(target).to receive(:build_transport).and_return(fake)
    fake
  end

  it "overrides the family-resolved api_key for a single call" do
    fake = with_fake_transport(client)
    options = Nfe::RequestOptions.new(api_key: "tenant-key")

    client.request(:get, family: :main, path: "/v1/companies", request_options: options)

    expect(fake.requests.last.headers["X-NFE-APIKEY"]).to eq("tenant-key")
  end

  it "falls back to family resolution for nil fields" do
    fake = with_fake_transport(client)
    options = Nfe::RequestOptions.new(api_key: nil, base_url: nil, timeout: 90)

    client.request(:get, family: :main, path: "/v1/companies", request_options: options)

    sent = fake.requests.last
    expect(sent.headers["X-NFE-APIKEY"]).to eq("client-key")
    expect(sent.base_url).to eq("https://api.nfe.io")
    expect(sent.read_timeout).to eq(90)
  end

  it "lets two tenants share one client with distinct per-call keys" do
    fake = with_fake_transport(client)

    client.request(:get, family: :main, path: "/v1/companies",
                         request_options: Nfe::RequestOptions.new(api_key: "tenant-a"))
    client.request(:get, family: :main, path: "/v1/companies",
                         request_options: Nfe::RequestOptions.new(api_key: "tenant-b"))

    keys = fake.requests.map { |r| r.headers["X-NFE-APIKEY"] }
    expect(keys).to eq(%w[tenant-a tenant-b])
  end
end
