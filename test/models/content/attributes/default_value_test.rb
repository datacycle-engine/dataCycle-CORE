# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Content
    module Attributes
      class DefaultValueTest < ActiveSupport::TestCase
        def set_default_value(template_name, key, value, content = nil)
          template = content || DataCycleCore::ThingTemplate.find_by(template_name:)

          if value.blank?
            template.schema['properties'][key].delete('default_value')
          else
            template.schema['properties'][key]['default_value'] = value
          end

          template.update_column(:schema, template.schema) if template.is_a?(DataCycleCore::ThingTemplate)
          template.remove_instance_variable(:@default_value_property_names) if template.instance_variable_defined?(:@default_value_property_names)

          template
        end

        test 'set data property (stored as json root value) with default_value does not overwrite original value' do
          set_default_value('Bild', 'upload_date', Date.current.to_s)

          data = { 'name' => 'Testbild', 'upload_date' => 2.days.ago.to_date }
          data_set = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: data)

          assert_equal(2.days.ago.to_date, data_set.upload_date)
          assert_equal(2.days.ago.to_date.as_json, data_set.get_data_hash.dig('upload_date'))
        end

        test 'set data property (stored as root translated_value) with default_value does not overwrite original value' do
          template = set_default_value('Bild', 'upload_date', Date.current.to_s)
          template.schema['properties']['upload_date']['storage_location'] = 'translated_value'
          template.update_column(:schema, template.schema)

          data = { 'name' => 'Testbild', 'upload_date' => 2.days.ago.to_date }
          data_set = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: data)

          assert_equal(2.days.ago.to_date, data_set.upload_date)
          assert_equal(2.days.ago.to_date.as_json, data_set.get_data_hash.dig('upload_date'))
        end

        test 'set data property (stored as object in value) with default_value, does not overwrite original value' do
          template = DataCycleCore::ThingTemplate.find_by(template_name: 'Artikel')
          template.schema['properties']['validity_period']['properties']['valid_from']['default_value'] = Date.current.to_s
          template.update_column(:schema, template.schema)

          data = { 'name' => 'TestArtikel', 'validity_period' => { 'valid_from' => 2.days.ago.to_date } }
          data_set = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: data)

          assert_equal(2.days.ago.to_date, data_set.validity_period.valid_from)
          assert_equal(2.days.ago.to_date, data_set.get_data_hash.dig('validity_period', 'valid_from'))
        end

        test 'set data property (stored as object in translated_value) with default_value, does not overwrite original data' do
          template = DataCycleCore::ThingTemplate.find_by(template_name: 'Artikel')
          template.schema['properties']['validity_period']['properties']['valid_from']['default_value'] = Date.current.to_s
          template.schema['properties']['validity_period']['storage_location'] = 'translated_value'
          template.schema['properties']['validity_period']['properties']['valid_from']['storage_location'] = 'translated_value'
          template.schema['properties']['validity_period']['properties']['valid_until']['storage_location'] = 'translated_value'
          template.update_column(:schema, template.schema)

          data = { 'name' => 'TestArtikel', 'validity_period' => { 'valid_from' => 2.days.ago.to_date } }
          data_set = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: data)

          assert_equal(2.days.ago.to_date, data_set.validity_period.valid_from)
          assert_equal(2.days.ago.to_date, data_set.get_data_hash.dig('validity_period', 'valid_from'))
        end

        test 'set data property (stored in column) with default_value does not overwrite original data' do
          set_default_value('Bild', 'description', Date.current.to_s)

          data = { 'name' => 'Testbild', 'description' => 'Hallo' }
          data_set = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: data)

          assert_equal('Hallo', data_set.description)
          assert_equal('Hallo', data_set.get_data_hash.dig('description'))
        end

        test 'create thing with data_hash_service/create_internal_object' do
          data_type = DataCycleCore::Classification.for_tree('Inhaltstypen').find_by(name: 'Bild')
          params = {
            datahash: {
              name: 'TestBild 1'
            }
          }.with_indifferent_access

          content = DataCycleCore::DataHashService.create_internal_object('Bild', params, nil)

          assert_equal params.dig(:datahash, :name), content.name
          assert_equal data_type.id, content.data_type.first.id
        end

        test 'create thing with data_hash_service/create_internal_object with multiple languages' do
          data_type = DataCycleCore::Classification.for_tree('Inhaltstypen').find_by(name: 'Bild')
          params = {
            translations: {
              de: {
                name: 'TestBild 1'
              },
              en: {
                name: 'TestBild 1 en'
              }
            }
          }.with_indifferent_access

          content = DataCycleCore::DataHashService.create_internal_object('Bild', params, nil)

          I18n.with_locale(:en) do
            assert_equal params.dig(:translations, :en, :name), content.name
          end

          assert_equal params.dig(:translations, :de, :name), content.name
          assert_equal data_type.id, content.data_type.first.id
        end

        test 'setting default_value again does not override existing value' do
          upload_date = 2.days.ago.to_date
          set_default_value('Bild', 'upload_date', Date.current.to_s)

          data = { 'name' => 'Testbild', 'upload_date' => upload_date }
          data_set = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: data)

          assert_equal(upload_date, data_set.upload_date)
          assert_equal(upload_date.as_json, data_set.get_data_hash.dig('upload_date'))

          data_hash = {}
          data_set.add_default_values(data_hash:, force: true)
          data_set.set_data_hash(data_hash:, partial_update: true)

          assert_equal(upload_date, data_set.upload_date)
          assert_equal(upload_date.as_json, data_set.get_data_hash.dig('upload_date'))
        end
      end
    end
  end
end
