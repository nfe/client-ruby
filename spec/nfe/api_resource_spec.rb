require_relative '../rspec_helper'

describe Nfe::ApiResource, :vcr do
  before(:each) do
    Nfe.api_key('e12cmDevG5iLhSd9Y7BOpxynL86Detjd2R1D5jsP5UGXA8gwxug0Vojl3H9TIzBpbhI')
  end

  it 'call Nfe API' do
    url = "/v1/companies"
    method = :get

    response = Nfe::Company.api_request(url, method)
    expect(response['companies'].class).to eq(Array)
  end

  it 'should throw error' do
    url = "/v1/companies"
    method = :post

    params = {exp_month: 5,
              exp_year: 2017,
              cvc: '021',
              name: 'Doctor Who'
    }

    expect{ Nfe::Company.api_request(url, method, params) }.to raise_error Nfe::NfeError

  end

  it 'should create NfeError with error message and http code' do
    http_code = 400
    json_message = {error: {type: '', message: 'Error Message'}}
    http_message = ''
    message = 'Error Message'
    nfe_error = Nfe::NfeError.new(http_code, json_message, http_message, message)
    expect(nfe_error.http_status).to eq(http_code)
    expect(nfe_error.json_message).to eq(json_message)
    expect(nfe_error.http_message).to eq(http_message)
    expect(nfe_error.message).to eq(message)
  end
end
