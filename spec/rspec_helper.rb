require 'rspec'
require 'byebug'
require 'vcr'
require 'webmock'
require_relative '../lib/nfe'

VCR.configure do |config|
  config.cassette_library_dir = "./vcr_cassettes"
  config.hook_into :webmock
  config.ignore_localhost = true
  config.configure_rspec_metadata!
end

