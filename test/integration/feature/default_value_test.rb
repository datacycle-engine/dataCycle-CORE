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
        template = content || DataCycleCore::ThingTemplate.find_by(template_name:)

        if value.blank?
          template.schema['properties'][key].delete(type_name)
        else
          template.schema['properties'][key][type_name] = value
        end

        template.update_column(:schema, template.schema) if template.is_a?(DataCycleCore::ThingTemplate)
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
        assert_equal 'application/json; charset=utf-8', response.content_type
        json_data = JSON.parse response.body

        assert json_data['valid']
        assert_empty json_data['errors']
        assert_empty json_data['warnings']
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
        assert_equal 'application/json; charset=utf-8', response.content_type
        json_data = JSON.parse response.body

        assert json_data['valid']
        assert_empty json_data['errors']
        assert_empty json_data['warnings']
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
        assert_equal 'application/json; charset=utf-8', response.content_type
        json_data = JSON.parse response.body

        assert json_data['valid']
        assert_empty json_data['errors']
        assert_empty json_data['warnings']
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
        assert_equal 'application/json; charset=utf-8', response.content_type
        json_data = JSON.parse response.body
        assert_not json_data['valid']
        assert_equal 1, json_data['errors'].size
        assert_empty json_data['warnings']
      end

      # activate when it is possible to set default_values in embedded for validation purposes
      # test 'validation works in embedded objects' do
      #   @content2 = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'DefaultValueArtikelTest' })

      #   set_schema_attribute_value('Action', 'name', 'default_value', 'TranslatedOverlayAttributeDefaultValue')
      #   set_schema_attribute_value('Action', 'name', 'validations', {
      #     required: true
      #   })

      #   post validate_thing_path(@content2),
      #        xhr: true,
      #        params: {
      #          thing: {
      #            datahash: {
      #              potential_action: {
      #                '0': {
      #                  name: ''
      #                }
      #              }
      #            }
      #          }
      #        }

      #   assert_response :success
      #   assert_equal 'application/json; charset=utf-8', response.content_type
      #   json_data = JSON.parse response.body
      #   assert_empty json_data['error']
      #   assert_empty json_data['warning']
      # end
    end
  end
end
