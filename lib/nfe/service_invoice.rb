module Nfe
  class ServiceInvoice < NfeObject
    include ApiResource
    include ApiOperations::Create
    include ApiOperations::List
    include ApiOperations::Retrieve
    include ApiOperations::Delete
    include ApiOperations::Update
    include ApiOperations::Download

    def self.company_id(company_id)
      @company_id = company_id
    end

    def self.url
      "/v1/companies/#{@company_id}/serviceinvoices"
    end

    def url
      "#{self.class.url}/#{self.id}"
    end

    def self.create_from(params)
      params
    end
  end
end