# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Utility
    module DefaultValue
      class StringTest < DataCycleCore::TestCases::ActiveSupportTestCase
        def subject
          DataCycleCore::Utility::DefaultValue::String
        end

        test 'substitution formats the configured template with the slug parameter and content id' do
          content = struct_double(id: 'thing-1')
          value = subject.substitution(
            content:,
            property_definition: { 'default_value' => { 'value' => 'preview/%<slug>s/%<id>s' } },
            property_parameters: { 'slug' => 'my-slug' }
          )

          assert_equal('preview/my-slug/thing-1', value)
        end

        test 'substitution returns nil for a blank template' do
          assert_nil(subject.substitution(content: nil, property_definition: {}, property_parameters: {}))
        end

        test 'current_user renders the user as a formatted string' do
          user = struct_double(given_name: 'Ada', family_name: 'Lovelace', email: 'ada@example.com')

          assert_equal('Ada Lovelace <ada@example.com>', subject.current_user(current_user: user))
        end

        test 'current_user returns nil without a user' do
          assert_nil(subject.current_user(current_user: nil))
        end

        test 'linked_gip_route_attribute returns nil when no linked id is present' do
          assert_nil(subject.linked_gip_route_attribute(property_parameters: { 'linked' => nil }, property_definition: {}))
        end

        test 'linked_gip_route_attribute reads the configured attribute from the linked thing' do
          DataCycleCore::Thing.stub(:find_by, struct_double(route_name: 'Route 7')) do
            value = subject.linked_gip_route_attribute(
              property_parameters: { 'linked' => 'thing-1' },
              property_definition: { 'default_value' => { 'linked_attribute' => 'route_name' } }
            )

            assert_equal('Route 7', value)
          end
        end

        test 'copy_from_translation reads the key in the first available locale of the content' do
          content = struct_double(first_available_locale: :de, name: 'Name DE')

          assert_equal('Name DE', subject.copy_from_translation(content:, key: 'name'))
        end
      end
    end
  end
end
