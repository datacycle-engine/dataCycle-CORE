require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'

describe DataCycleCore::Organization do
  subject do
    template = DataCycleCore::Organization.find_by(template: true, template_name: 'Organization')
    data_set = DataCycleCore::Organization.new
    data_set.schema = template.schema
    data_set.template_name = template.template_name
    data_set.save
    data_set
  end

  describe 'insert data' do
    test_data = {
      'name' => 'Name',
      'legal_name' => 'Firmenname',
      'telephone' => '+ 43 123 456',
      'fax_number' => '+ 43 654 321',
      'email' => 'test@test.com',
      'address' => {
        'address_locality' => 'Test - Ort',
        'street_address' => 'Test - Strasse',
        'postal_code' => '1234'
      },
      'url' => 'http://firma.at',
      'description' => 'Short test description for company object.'
    }

    let(:organization) do
      subject.set_data_hash(data_hash: test_data)
      subject.save
      subject
    end

    after do
      organization.destroy_content
      organization.destroy

      organization.histories.each do |item|
        item.destroy_content
        item.destroy
      end
    end

    it 'extracts name' do
      organization.name.must_equal 'Name'
    end

    it 'extracts legal_name' do
      organization.legal_name.must_equal 'Firmenname'
    end

    it 'extracts telephone' do
      organization.telephone.must_equal '+ 43 123 456'
    end

    it 'extracts fax_number' do
      organization.fax_number.must_equal '+ 43 654 321'
    end

    it 'extracts email' do
      organization.email.must_equal 'test@test.com'
    end

    it 'extracts address' do
      organization.address.address_locality.must_equal 'Test - Ort'
      organization.address.street_address.must_equal 'Test - Strasse'
      organization.address.postal_code.must_equal '1234'
    end

    it 'extracts url' do
      organization.url.must_equal 'http://firma.at'
    end

    it 'extracts description' do
      organization.description.must_equal 'Short test description for company object.'
    end
  end
end
