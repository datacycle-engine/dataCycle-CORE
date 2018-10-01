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
      data_set.set_data_hash(
        data_hash: DataCycleCore::TestPreparations.load_dummy_data_hash('things', 'organization').merge(
          { 'contact_info' => DataCycleCore::TestPreparations.load_dummy_data_hash('things', 'contact_info') }
        )
      )

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
      assert_raises StandardError do
        data_set.set_data_hash(data_hash: DataCycleCore::TestPreparations.load_dummy_data_hash('things', 'organization'))
      end
    end
  end
end
