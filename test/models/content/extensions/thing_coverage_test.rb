# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Content
    module Extensions
      # Coverage for the Content::Extensions::Thing concern: schema-type dependent
      # title/desc/object_browser_fields branches, the address line/block builders,
      # coordinates, the relevant_* helpers and the deprecated class methods. Driven
      # by a lightweight host that includes the concern, no Thing record needed.
      class ThingCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
        class ThingHost
          include DataCycleCore::Content::Extensions::Thing

          attr_reader :schema_type, :template_name, :latitude, :longitude, :address

          def initialize(schema_type: 'Thing', template_name: 'Artikel', latitude: nil, longitude: nil, address: nil, address_property_type: nil, properties: [])
            @schema_type = schema_type
            @template_name = template_name
            @latitude = latitude
            @longitude = longitude
            @address = address
            @address_property_type = address_property_type
            @properties = properties
          end

          def job_title = 'CEO'
          def description = 'A description'
          def name = 'A Name'
          def given_name = 'John'
          def family_name = 'Doe'

          def properties_for(key)
            return { 'type' => @address_property_type } if key == 'address' && @address_property_type

            {}
          end

          def property?(attribute_name)
            @properties.include?(attribute_name)
          end
        end

        def address_double
          struct_double(postal_code: '6020', address_locality: 'Innsbruck', street_address: 'Maria-Theresien-Straße 1')
        end

        test 'desc returns the job title for a Person' do
          assert_equal('CEO', ThingHost.new(schema_type: 'Person').desc)
        end

        test 'object_browser_fields is empty for a generic schema type' do
          assert_equal([], ThingHost.new(schema_type: 'Thing').object_browser_fields)
        end

        test 'address_line is nil without an object address' do
          assert_nil(ThingHost.new.address_line)
        end

        test 'address_line builds a single-line address' do
          result = ThingHost.new(address: address_double, address_property_type: 'object').address_line

          assert_includes(result.to_s, '6020 Innsbruck')
        end

        test 'address_block builds a multi-line address' do
          result = ThingHost.new(address: address_double, address_property_type: 'object').address_block

          assert_includes(result.to_s, 'Maria-Theresien-Straße 1')
        end

        test 'coordinates formats latitude and longitude' do
          assert_equal('GPS: 47.26, 11.39', ThingHost.new(latitude: 47.264, longitude: 11.394).coordinates)
        end

        test 'relevant_template_names returns the template name' do
          assert_equal(['Artikel'], ThingHost.new(template_name: 'Artikel').relevant_template_names)
        end

        test 'relevant_property_names returns the attribute when it is a property' do
          assert_equal(['headline'], ThingHost.new(properties: ['headline']).relevant_property_names('headline'))
        end

        test 'relevant_property_names is empty for an unknown attribute' do
          assert_equal([], ThingHost.new(properties: []).relevant_property_names('headline'))
        end

        test 'deprecated class methods raise' do
          assert_raises(DataCycleCore::Error::DeprecatedMethodError) { ThingHost.from_time(nil) }
          assert_raises(DataCycleCore::Error::DeprecatedMethodError) { ThingHost.to_time(nil) }
          assert_raises(DataCycleCore::Error::DeprecatedMethodError) { ThingHost.sort_by_proximity }
        end
      end
    end
  end
end
