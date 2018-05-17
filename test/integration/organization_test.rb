require 'test_helper'

module DataCycleCore
  class OrganizationTest < ActiveSupport::TestCase
    test 'create an organization and read all attributes' do
      template = DataCycleCore::Organization.find_by(template: true, template_name: 'Organization')
      data_set = DataCycleCore::Organization.new
      data_set.schema = template.schema
      data_set.template_name = template.template_name
      data_set.save
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
      data_set.set_data_hash(data_hash: test_data)
      data_set.save

      organization = data_set
      assert_equal('Name', organization.name)
      assert_equal('Firmenname', organization.legal_name)
      assert_equal('+ 43 123 456', organization.telephone)
      assert_equal('+ 43 654 321', organization.fax_number)
      assert_equal('test@test.com', organization.email)
      assert_equal('Test - Ort', organization.address.address_locality)
      assert_equal('Test - Strasse', organization.address.street_address)
      assert_equal('1234', organization.address.postal_code)
      assert_equal('http://firma.at', organization.url)
      assert_equal('Short test description for company object.', organization.description)
    end
  end
end
