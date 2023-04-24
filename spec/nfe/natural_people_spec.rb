require_relative '../rspec_helper'

describe Nfe::NaturalPeople, :vcr do
  before(:each) do
    Nfe.api_key('e12cmDevG5iLhSd9Y7BOpxynL86Detjd2R1D5jsP5UGXA8gwxug0Vojl3H9TIzBpbhI')
    Nfe::NaturalPeople.company_id("55e8a2c9440c3b0b84ceaa12")
  end

  it 'should list all NaturalPeople' do
    natural_peoples_list = Nfe::NaturalPeople.list_all
    expect(natural_peoples_list.object).to eq('list')
    expect(natural_peoples_list.data.size).to be >= 1
  end

  it 'should retrieve a NaturalPeople' do
    natural_people = Nfe::NaturalPeople.retrieve("55eeebf8440c3b0b84ceb1a8")
    expect(natural_people.id).to eq("55eeebf8440c3b0b84ceb1a8")
    expect(natural_people.name).to eq("Ricardo Caldeira")
  end
end
