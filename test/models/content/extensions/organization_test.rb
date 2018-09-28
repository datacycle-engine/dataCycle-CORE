# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class OrganizationTest < ActiveSupport::TestCase
    test 'create an organization and read all attributes' do
      template = DataCycleCore::Thing.find_by(template: true, template_name: 'Organization')
      data_set = DataCycleCore::Thing.new
      data_set.schema = template.schema
      data_set.template_name = template.template_name
      data_set.save
      test_data = {
        'name' => 'Firmenname',
        'contact_info' => {
          'telephone' => '+ 43 123 456',
          'fax_number' => '+ 43 654 321',
          'email' => 'test@test.com',
          'url' => 'http://firma.at'
        },
        'address' => {
          'address_locality' => 'Test - Ort',
          'street_address' => 'Test - Strasse',
          'postal_code' => '1234',
          'address_country' => 'Austria'
        },
        'description' => 'Short test description for company object.'
      }
      data_set.set_data_hash(data_hash: test_data)
      data_set.save

      organization = data_set
      assert_equal('Firmenname', organization.name)
      assert_equal('+ 43 123 456', organization.contact_info.telephone)
      assert_equal('+ 43 654 321', organization.contact_info.fax_number)
      assert_equal('test@test.com', organization.contact_info.email)
      assert_equal('http://firma.at', organization.contact_info.url)
      assert_equal('Test - Ort', organization.address.address_locality)
      assert_equal('Test - Strasse', organization.address.street_address)
      assert_equal('1234', organization.address.postal_code)
      assert_equal('Austria', organization.address.address_country)
      assert_equal('Short test description for company object.', organization.description)
    end

    test 'expect an exception when template includes wrong data-type' do
      template = DataCycleCore::Thing.find_by(template: true, template_name: 'Organization')
      data_set = DataCycleCore::Thing.new
      data_set.schema = template.schema.merge('properties' => { 'test' => { 'label' => 'test', 'type' => 'test' } })
      data_set.template_name = template.template_name
      data_set.save
      test_data = {
        'name' => 'Firmenname',
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
      assert_raises StandardError do
        data_set.set_data_hash(data_hash: test_data)
      end
    end
  end
end
