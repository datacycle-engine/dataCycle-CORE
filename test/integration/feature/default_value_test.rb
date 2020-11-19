# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Feature
    class DefaultValueTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
      before(:all) do
        set_schema_attribute_value('Bild', 'name', 'default_value', 'TranslatedAttributeDefaultValue')
        @content = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'DefaultValueBildTest' })
      end

      setup do
        sign_in(User.find_by(email: 'tester@datacycle.at'))
      end

      def set_schema_attribute_value(template_name, key, type_name, value, content = nil)
        template = content || DataCycleCore::Thing.find_by(template: true, template_name: template_name)
        template.schema['properties'][key][type_name] = value
        template.save
        template
      end

      test 'validation works with default_values on creation' do
        post validate_things_path, xhr: true, params: {
          template: 'Bild',
          thing: {
            datahash: {
              name: ''
            }
          }
        }

        assert_response :success
        assert_equal 'application/json', response.content_type
        json_data = JSON.parse response.body

        assert_empty json_data['error']
        assert_empty json_data['warning']
      end

      test 'validation works with default_values in new language' do
        post validate_thing_path(@content), xhr: true, params: {
          locale: 'en',
          thing: {
            datahash: {
              name: ''
            }
          }
        }

        assert_response :success
        assert_equal 'application/json', response.content_type
        json_data = JSON.parse response.body

        assert_empty json_data['error']
        assert_empty json_data['warning']
      end

      test 'validation works with default_values on creation of translated content' do
        post validate_things_path, xhr: true, params: {
          template: 'Bild',
          thing: {
            translations: {
              de: {
                name: ''
              }
            }
          }
        }

        assert_response :success
        assert_equal 'application/json', response.content_type
        json_data = JSON.parse response.body

        assert_empty json_data['error']
        assert_empty json_data['warning']
      end

      test 'validation works with deleting attributes with default_values' do
        post validate_thing_path(@content), xhr: true, params: {
          thing: {
            datahash: {
              name: ''
            }
          }
        }

        assert_response :success
        assert_equal 'application/json', response.content_type
        json_data = JSON.parse response.body
        assert_equal 1, json_data['error'].size
        assert_empty json_data['warning']
      end

      test 'validation works in embedded objects' do
        set_schema_attribute_value('BildOverlay', 'name', 'default_value', 'TranslatedOverlayAttributeDefaultValue')
        set_schema_attribute_value('BildOverlay', 'name', 'validations', {
          required: true
        })

        post validate_thing_path(@content),
             xhr: true,
             params: {
               thing: {
                 datahash: {
                   overlay: {
                     '0': {
                       name: ''
                     }
                   }
                 }
               }
             }

        assert_response :success
        assert_equal 'application/json', response.content_type
        json_data = JSON.parse response.body
        assert_empty json_data['error']
        assert_empty json_data['warning']
      end
    end
  end
end
