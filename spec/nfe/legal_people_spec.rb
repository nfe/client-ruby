require_relative '../rspec_helper'

describe Nfe::LegalPeople, :vcr do
  before(:each) do
    Nfe.api_key('e12cmDevG5iLhSd9Y7BOpxynL86Detjd2R1D5jsP5UGXA8gwxug0Vojl3H9TIzBpbhI')
    Nfe::LegalPeople.company_id("55df4dc6b6cd9007e4f13ee8")
  end

  it 'should list all LegalPeople' do
    natural_peoples_list = Nfe::LegalPeople.list_all
    expect(natural_peoples_list.object).to eq('list')
    expect(natural_peoples_list.data.size).to be >= 0
  end

  it 'should retrieve a LegalPeople' do
    customer_params = {borrower: { federalTaxNumber: '69919334000160', name: 'Empresa Teste', email: 'ricardo.nezz@mailinator.com',
                                   postalCode: '21231110', street: 'Rua Do Cliente', number: '1310', additionalInformation: 'AP 202',
                                   district: 'Centro', city_code: 4204202, city_name: 'Chapecó', city_state: 'SC' }}

    service_params = { cityServiceCode: '0107', description: 'Manutenção e suporte técnico.', servicesAmount: 0.15 }

    Nfe::ServiceInvoice.company_id("55df4dc6b6cd9007e4f13ee8")
    nfe = Nfe::ServiceInvoice.create(customer_params.merge(service_params))

    natural_people = Nfe::LegalPeople.retrieve("55ef27f8440c3b0b84cebc2d")
    expect(natural_people.id).to eq("55ef27f8440c3b0b84cebc2d")
    expect(natural_people.name).to eq("Nome da Empresa")
  end
end
