require 'byebug'

module Nfe
  module ApiOperations
    module Download
      def download(nfe_id, file_format)
        if file_format != :pdf && file_format != :xml
          rcode = '422'
          message = 'Invalid file format. Only :pdf or :xml are supported'
          formatted = { error: message }
          raise NfeError.new(rcode, formatted, formatted, message)
        else
          url = "#{self.url}/#{nfe_id}/#{file_format}"
          method = :get
          api_request_file(url, method)
        end
      end

      def self.included(base)
        base.extend(Download)
      end
    end
  end
end
