require_relative 'lib/net/http/ntlm_auth/version'

Gem::Specification.new do |spec|
  spec.name          = "net-http-ntlm_auth"
  spec.version       = Net::HTTP::NTLMAuth::VERSION
  spec.authors       = ["labocho"]
  spec.email         = ["labocho@penguinlab.jp"]

  spec.summary       = "Add support NTLM authentication to net/http"
  spec.description   = "Add support NTLM authentication to net/http"
  spec.homepage      = "https://github.com/socioart/net-http-ntlm_auth"
  spec.license       = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.3.0")

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/socioart/net-http-ntlm_auth"
  spec.metadata["changelog_uri"] = "https://github.com/socioart/net-http-ntlm_auth/blob/master/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "ntlm-http", "~> 0.1.1"
end
