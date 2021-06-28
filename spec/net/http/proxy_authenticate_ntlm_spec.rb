RSpec.describe Net::HTTP::ProxyAuthenticateNTLM do
  it "has a version number" do
    expect(Net::HTTP::ProxyAuthenticateNTLM::VERSION).not_to be nil
  end

  # http_proxy=http://PROXY_USER:PROXY_PASSWORD@PROXY_ADDRESS:PROXY_PASSWORD bin/rspec spec
  context "http_proxy env provided" do
    let(:proxy) { URI.parse(ENV.fetch("http_proxy")) }

    before do
      skip "http_proxy env was not provided" unless ENV["http_proxy"]
      Net::HTTP::ProxyAuthenticateNTLM.enabled = true
    end

    it "should get from http://example.com" do
      http = Net::HTTP.new("example.com", 80, proxy.hostname, proxy.port, proxy.user, proxy.password)
      res = http.start do |h|
        h.get("/")
      end
      expect(res.code).to eq "200"
    end

    it "should get from https://example.com" do
      http = Net::HTTP.new("example.com", 443, proxy.hostname, proxy.port, proxy.user, proxy.password)
      http.use_ssl = true
      res = http.start do |h|
        h.get("/")
      end
      expect(res.code).to eq "200"
    end

  end
end
