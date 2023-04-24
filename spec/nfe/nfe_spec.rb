require_relative '../rspec_helper'

describe Nfe, :vcr do
  it 'has a version number' do
    expect(Nfe::VERSION).not_to be nil
  end

  it 'should set api key' do
    Nfe.api_key('e12cmDevG5iLhSd9Y7BOpxynL86Detjd2R1D5jsP5UGXA8gwxug0Vojl3H9TIzBpbhI')
    expect(Nfe.access_keys).to eq('e12cmDevG5iLhSd9Y7BOpxynL86Detjd2R1D5jsP5UGXA8gwxug0Vojl3H9TIzBpbhI')
  end

  it 'should get empty access keys' do
    Nfe.api_key('')
    expect(Nfe.access_keys).to eq("")
  end

  describe Nfe::NfeObject do
    it 'should convert to hash' do
      params_2 = {a: 1, b: 'b'}
      params = {a: 'a', b: 'b', c: 1, d: Nfe::NfeObject.create_from(params_2), e:[a: 'a', b: 1, c: Nfe::NfeObject.create_from(params_2)]}
      obj = Nfe::NfeObject.create_from(params)
      expect(obj.to_hash).to eq(params.merge({d: params_2, e: [a: 'a', b: 1, c: params_2]}))
    end

    it 'should convert to json' do
      params_2 = {a: 1, b: 'b'}
      params = {a: 'a', b: 'b', c: 1, d: Nfe::NfeObject.create_from(params_2), e:[a: 'a', b: 1, c: Nfe::NfeObject.create_from(params_2)]}
      obj = Nfe::NfeObject.create_from(params)
      expect(obj.to_json).to eq(params.to_json)
    end

    it 'should convert to string' do
      params_2 = {a: 1, b: 'b'}
      params = {a: 'a', b: 'b', c: 1, d: Nfe::NfeObject.create_from(params_2), e:[a: 'a', b: 1, c: Nfe::NfeObject.create_from(params_2)]}
      obj = Nfe::NfeObject.create_from(params)
      expect(obj.to_s).to eq(params.to_json.to_s)
    end
  end
end
