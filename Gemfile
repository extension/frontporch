source 'http://rubygems.org'
source 'https://systems.extension.org/rubygems/'

gem 'rails', '2.3.18'
# rdoc - removes a warning
gem 'rdoc'
# database
gem 'mysql'
# pagination
gem 'will_paginate'
# command line tools
gem 'thor'
# csv output/import
gem 'fastercsv'
# authentication
gem 'ruby-openid'
# polymorphic HMT assocations
gem 'has_many_polymorphs'
# atom parsing
gem 'ratom', :require => 'atom'
# extended tz management
gem 'tzinfo'
# ip to geo mapping
gem 'geokit'
gem 'geoip'
# html and link manipulation
gem 'nokogiri'
gem 'hpricot'
# image submission and other image handling
gem 'paperclip'
gem 'rmagick', :require => false
# CSE management
gem 'gdata'
# cron management
gem 'lockfile'
# needed for mail fetching and parsing
gem 'SystemTimer'
gem 'mail'
# arel syntax for rails2
gem 'fake_arel'
# microformats
gem 'mofo'
# widget related
gem 'rest-client'
gem 'json_pure'
# command line
gem 'thor'
gem 'trollop', '1.16.2'
#get image attributes
gem 'fastimage'
# handle rewrites of trailing slashes
gem 'rack-rewrite'

#airbrake
gem 'airbrake', '3.1.2'

# authentication
gem 'omniauth', "~> 1.0"
gem 'omniauth-openid'

# To use debugger (ruby-debug for Ruby 1.8.7+, ruby-debug19 for Ruby 1.9.2+)
# gem 'ruby-debug'
# gem 'ruby-debug19', :require => 'ruby-debug'

# monitoring
gem 'newrelic_rpm'

# Bundle gems for the local environment. Make sure to
# put test-only gems in this group so their generators
# and rake tasks are available in development mode:
group :development, :test do
  gem 'wirble'
  gem "awesome_print"
  gem "map_by_method"
  gem "what_methods"
  #gem "net-http-spy"  # not useable with the savon gem, results in SystemStackError: stack level too deep on requests
  gem "powder"
  #gem "rails-footnotes", '< 3.7.0'
  # Deploy with Capistrano
  gem 'capistrano'
  # log stuff
  gem 'capatross'
end
