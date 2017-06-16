require "rest-client"
require "json"
require "nfe/version"
require "nfe/configuration"

require "nfe/api_resource"
require "nfe/api_operations/create"
require "nfe/api_operations/delete"
require "nfe/api_operations/list"
require "nfe/api_operations/retrieve"
require "nfe/api_operations/update"
require "nfe/api_operations/download"

require "nfe/nfe_object"
require "nfe/service_invoice"
require "nfe/company"
require "nfe/natural_people"
require "nfe/legal_people"

require "nfe/util"
require "nfe/errors/nfe_error"


module Nfe
  @@api_key = ''

  def self.api_key(api_key)
    @@api_key = api_key
  end

  def self.access_keys
    "#{@@api_key}"
  end

  def self.configuration
    @configuration ||= Configuration.new
  end

  def self.configure
    yield(configuration) if block_given?
  end
end
