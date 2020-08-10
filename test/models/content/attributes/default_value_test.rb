# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Content
    module Attributes
      class DefaultValueTest < ActiveSupport::TestCase
        def set_default_value(template_name, key, value, content = nil)
          template = content || DataCycleCore::Thing.find_by(template: true, template_name: template_name)
          template.schema['properties'][key]['default_value'] = value
          template.save
          template
        end

        test 'set data property (stored as json root value) with default_value does not overwrite original value' do
          set_default_value('Bild', 'upload_date', Time.zone.now.beginning_of_day.to_s)

          data = { 'name' => 'Testbild', 'upload_date' => 2.days.ago.beginning_of_day }
          data_set = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: data)

          assert_equal(2.days.ago.beginning_of_day, data_set.upload_date)
          assert_equal(2.days.ago.beginning_of_day, data_set.get_data_hash.dig('upload_date'))
        end

        test 'set data property (stored as root translated_value) with default_value does not overwrite original value' do
          template = set_default_value('Bild', 'upload_date', Time.zone.now.beginning_of_day.to_s)
          template.schema['properties']['upload_date']['storage_location'] = 'translated_value'
          template.save

          data = { 'name' => 'Testbild', 'upload_date' => 2.days.ago.beginning_of_day }
          data_set = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: data)

          assert_equal(2.days.ago.beginning_of_day, data_set.upload_date)
          assert_equal(2.days.ago.beginning_of_day, data_set.get_data_hash.dig('upload_date'))
        end

        test 'set data property (stored as object in value) with default_value, does not overwrite original value' do
          template = DataCycleCore::Thing.find_by(template: true, template_name: 'Artikel')
          template.schema['properties']['validity_period']['properties']['valid_from']['default_value'] = Time.zone.now.beginning_of_day.to_s
          template.save

          data = { 'name' => 'TestArtikel', 'validity_period' => { 'valid_from' => 2.days.ago.beginning_of_day } }
          data_set = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: data)

          assert_equal(2.days.ago.beginning_of_day, data_set.validity_period.valid_from)
          assert_equal(2.days.ago.beginning_of_day, data_set.get_data_hash.dig('validity_period', 'valid_from'))
        end

        test 'set data property (stored as object in translated_value) with default_value, does not overwrite original data' do
          template = DataCycleCore::Thing.find_by(template: true, template_name: 'Artikel')
          template.schema['properties']['validity_period']['properties']['valid_from']['default_value'] = Time.zone.now.beginning_of_day.to_s
          template.schema['properties']['validity_period']['storage_location'] = 'translated_value'
          template.schema['properties']['validity_period']['properties']['valid_from']['storage_location'] = 'translated_value'
          template.schema['properties']['validity_period']['properties']['valid_until']['storage_location'] = 'translated_value'
          template.save

          data = { 'name' => 'TestArtikel', 'validity_period' => { 'valid_from' => 2.days.ago.beginning_of_day } }
          data_set = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: data)

          assert_equal(2.days.ago.beginning_of_day, data_set.validity_period.valid_from)
          assert_equal(2.days.ago.beginning_of_day, data_set.get_data_hash.dig('validity_period', 'valid_from'))
        end

        test 'set data property (stored in column) with default_value does not overwrite original data' do
          set_default_value('Bild', 'description', Time.zone.now.beginning_of_day.to_s)

          data = { 'name' => 'Testbild', 'description' => 'Hallo' }
          data_set = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: data)

          assert_equal('Hallo', data_set.description)
          assert_equal('Hallo', data_set.get_data_hash.dig('description'))
        end
      end
    end
  end
end
