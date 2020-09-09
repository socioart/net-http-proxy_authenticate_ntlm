# bundle exec ruby examples/openuri.rb http://proxyuser:proxypass@proxyaddress:proxyport
require "net/http/ntlm_auth"
require "rest-client"

Net::HTTP::NTLMAuth.enabled = true
proxy_uri = URI.parse(ARGV.first)

RestClient.proxy = proxy_uri.to_s
puts RestClient.get("http://example.com")
