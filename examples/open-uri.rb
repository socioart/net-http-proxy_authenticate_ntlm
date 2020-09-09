# bundle exec ruby examples/openuri.rb http://proxyuser:proxypass@proxyaddress:proxyport
require "net/http/proxy_authenticate_ntlm"
require "open-uri"

Net::HTTP::ProxyAuthenticateNTLM.enabled = true
proxy_uri = URI.parse(ARGV.first)

puts OpenURI.open_uri("http://example.com", proxy: proxy_uri.to_s, &:read)
