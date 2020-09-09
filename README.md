# Net::Http::ProxyAuthenticateNTLM

Add support HTTP proxy using NTLM authentication to net/http.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'net-http-proxy_authenticate_ntlm', git: "https://github.com/socioart/net-http-proxy_authenticate_ntlm.git"
```

And then execute:

    $ bundle install

## Usage

```ruby
require "net/http"
require "net/http/proxy_authenticate_ntlm"

# Required
Net::HTTP::ProxyAuthenticateNTLM.enabled = true

# start with proxy information
Net::HTTP.start("example.com", nil, proxy_address, proxy_port, proxy_user, proxy_password) {|http|
  res = http.get("/")
  puts res.body
}
```

Many library (like open-uri or rest-client) uses net/http, then they can use NTLM protected proxy.

```ruby
require "open-uri"
require "net/http/proxy_authenticate_ntlm"

# Required
Net::HTTP::ProxyAuthenticateNTLM.enabled = true

# proxy_uri is string formed http://proxy_user:proxy_password@proxy_address:proxy_port
puts OpenURI.open_uri("http://example.com", proxy: proxy_uri, &:read)
```

```ruby
require "rest-client"
require "net/http/proxy_authenticate_ntlm"

# Required
Net::HTTP::ProxyAuthenticateNTLM.enabled = true

# proxy_uri is string formed http://proxy_user:proxy_password@proxy_address:proxy_port
RestClient.proxy = proxy_uri
puts RestClient.get("http://example.com")
```

Test with your proxy by exapmples/*.rb

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/labocho/net-http-proxy_authenticate_ntlm.


## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
