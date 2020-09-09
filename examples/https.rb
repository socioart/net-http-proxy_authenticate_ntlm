# bundle exec ruby examples/https.rb http://proxyuser:proxypass@proxyaddress:proxyport
require "net/http/proxy_authenticate_ntlm"

Net::HTTP::ProxyAuthenticateNTLM.enabled = true
proxy_uri = URI.parse(ARGV.first)

Net::HTTP.start("example.com", nil, proxy_uri.host, proxy_uri.port, proxy_uri.user, proxy_uri.password, use_ssl: true) {|http|
  res = http.get("/")
  p res
  puts res.body
}
