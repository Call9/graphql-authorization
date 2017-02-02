$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "graphql_authorization/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "graphql_authorization"
  s.version     = GraphqlAuthorization::VERSION
  s.authors     = ["Matthew Chang"]
  s.email       = ["matthew@callnine.com"]
  s.homepage    = "https://www.call9.com"
  s.summary     = "An authorization framework for graphql-ruby"
  s.description = "An authorization framework for graphql-ruby"
  s.license     = "MIT"

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.rdoc"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency "rails", "~> 4.2.0"
  s.add_dependency "graphql", "~> 1.4.2"

  s.add_development_dependency "sqlite3"
  s.add_development_dependency "rspec"
end
