require_relative '../rspec_helper'

describe Nfe::ServiceInvoice do
  before(:each) do
    Nfe.api_key('e12cmDevG5iLhSd9Y7BOpxynL86Detjd2R1D5jsP5UGXA8gwxug0Vojl3H9TIzBpbhI')
    Nfe::ServiceInvoice.company_id("55df4dc6b6cd9007e4f13ee8")
  end

  it 'should create a ServiceInvoice' do
    customer_params = {borrower: { federalTaxNumber: '01946377198',
                                   name: 'Ricardo Caldeira',
                                   email: 'ricardo.nezz@mailinator.com',
                                   address: {
                                       country: 'BRA',
                                       postalCode: '22231110',
                                       street: 'Rua Do Cliente',
                                       number: '1310',
                                       additionalInformation: 'AP 202',
                                       district: 'Centro',
                                       city: {
                                           code: 4204202,
                                           name: 'Chapecó'
                                       },
                                       state: 'SC'
                                   }}}
    service_params = { cityServiceCode: '2690', description: 'Manutenção e suporte técnico.', servicesAmount: 0.15 }
    nfe = Nfe::ServiceInvoice.create(customer_params.merge(service_params))

    expect(nfe["environment"]).to eq('Development')
    expect(nfe["borrower"]["name"]).to eq('Ricardo Caldeira')
  end

  it 'should list all service invoices' do
    service_invoices_list = Nfe::ServiceInvoice.list_all
    expect(service_invoices_list["totalResults"]).to be >= 1
    expect(service_invoices_list["serviceInvoices"].size).to be >= 1
  end

  it 'should list service invoices by page' do
    service_invoices_list = Nfe::ServiceInvoice.list_all(pageCount: 5, pageIndex: 2)
    expect(service_invoices_list["totalResults"]).to be >= 1
    expect(service_invoices_list["totalPages"]).to be >= 1
    expect(service_invoices_list["page"]).to eq(2)
    expect(service_invoices_list["serviceInvoices"].size).to be >= 1
  end

  it 'should retrieve a ServiceInvoice' do
    service_invoices_list = Nfe::ServiceInvoice.list_all
    service_invoice_params = service_invoices_list["serviceInvoices"].first
    service_invoice = Nfe::ServiceInvoice.retrieve(service_invoice_params["id"])
    expect(service_invoice["id"]).to eq(service_invoice_params["id"])
    expect(service_invoice["rpsStatus"]).to eq("Normal")
  end

  it 'should cancel a ServiceInvoice' do
    skip "To be implemented"
    service_invoices_list = Nfe::ServiceInvoice.list_all
    service_invoice = service_invoices_list["serviceInvoices"].first
    response = Nfe::ServiceInvoice.delete(service_invoice["id"])
    expect(response).to eq("{}")
  end

  it 'should send a email to Tomador' do
    skip "To be implemented"
  end

  it 'should retrieve a ServiceInvoice pdf file' do
    skip "To be implemented"
    service_invoices_list = Nfe::ServiceInvoice.list_all
    service_invoice_params = service_invoices_list["serviceInvoices"].first
    response = Nfe::ServiceInvoice.download(service_invoice_params["id"], :pdf)
    expect(response.headers["Content-Type"]).to eq("application/pdf")
    expect(response.headers["Content-Disposition"]).to eq("attachment; filename=\"<invoice_name>.pdf\"")
  end

  it 'should get a ServiceInvoice xml file' do
    # skip "To be implemented"
    service_invoices_list = Nfe::ServiceInvoice.list_all
    service_invoice_params = service_invoices_list["serviceInvoices"].first
    response = Nfe::ServiceInvoice.download(service_invoice_params["id"], :xml)
    expect(response.headers["Content-Type"]).to eq("application/xml")
    expect(response.headers["Content-Disposition"]).to eq("attachment; filename=\"<invoice_name>.xml\"")
  end

  it 'should retrieve Service Invoices from Prefeitura' do
    skip "To be implemented"
  end

end
