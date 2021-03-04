
$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "hanuman/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "hanuman"
  s.version     = Hanuman::VERSION
  s.authors     = ["Kristen Hazard", "David Simmons"]
  s.email       = "info@suntouchersoftware.com"
  s.homepage    = "https://github.com/kristenhazard/hanuman"
  s.summary     = "Hanuman. The Hindu monkey god. An open source rails clone of survey monkey."
  s.description = "Hanuman. The Hindu monkey god. An open source rails clone of survey monkey."

  s.files = Dir["{app,config,db,lib,vendor}/**/*", "MIT-LICENSE", "Rakefile", "README.rdoc"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency 'rails', '~> 4.2.10'
  s.add_dependency 'responders', '~> 2.0'
  s.add_dependency 'paper_trail', '~> 6.0'
  s.add_dependency 'ancestry' #, '~> 3.0.2'
  s.add_dependency 'amoeba', '~> 3.1.0'
  s.add_dependency 'haml-rails', '~> 0.5.3'
  s.add_dependency 'coffee-rails', '~> 4.0.1'
  s.add_dependency 'sass-rails', '~> 4.0.3'
  s.add_dependency 'uglifier', '~> 2.5.3'
  s.add_dependency 'modernizr-rails', '~> 2.7.1'
  s.add_dependency 'jquery-rails', '~> 3.1.1'
  s.add_dependency 'ember-cli-rails', '~> 0.10.0'
  s.add_dependency 'cocaine', '~> 0.5.8'
  s.add_dependency 'kaminari', '~> 0.16.1'
  s.add_dependency 'active_model_serializers', '~> 0.8.1'
  s.add_dependency 'acts-as-taggable-on', '~> 4.0.0'
  s.add_dependency 'roo', '~> 2.3.2'
  # must stay on this version of carrierwave
  # upgrading to 1.0 or 1.1 broke the API on survey create - photo hash was empty-kdh
  s.add_dependency 'carrierwave', '1.3.2'
  s.add_dependency 'cloudinary', '~> 1.8.1'
  s.add_dependency 'sidekiq', '~> 3.5.0'
  s.add_dependency 'gmaps4rails', '~> 2.1.2'
  s.add_dependency 'pg_search', '~> 2.0.1'

  s.add_development_dependency 'pg', '0.18.4'
  s.add_development_dependency 'pry', '0.11.3'
  s.add_development_dependency 'foreigner'
  s.add_development_dependency "rspec-rails", "~> 3.4"
  s.add_development_dependency "database_cleaner"
  s.add_development_dependency "shoulda-matchers", '~> 3.1.2'
  s.add_development_dependency "shoulda-callback-matchers", '~>   1.1.4'
  s.add_development_dependency 'factory_bot_rails', '~> 4.11.1'
  s.add_development_dependency "fakeweb", "~> 1.3"
  s.add_development_dependency "faker", "~> 1.6.5"
  s.add_development_dependency "rubocop", "~> 0.40.0"
  s.add_development_dependency "codeclimate-test-reporter", "~> 0.5.1"
end
