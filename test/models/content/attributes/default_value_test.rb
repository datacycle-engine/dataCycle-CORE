# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Content
    module Attributes
      class DefaultValueTest < ActiveSupport::TestCase
        # test 'set data property (stored as json root value) with default_value' do
        #   data_set = DataCycleCore::TestPreparations.data_set_object('Bild')
        #   data_set.schema['properties']['upload_date']['default_value'] = Time.zone.now.beginning_of_day.to_s
        #   data_set.save

        #   data = { 'name' => 'Testbild' }
        #   data_set.set_data_hash(data_hash: data, update_search_all: false)
        #   data_set.save

        #   assert_equal(Time.zone.now.beginning_of_day, data_set.upload_date)
        #   assert_equal(Time.zone.now.beginning_of_day, data_set.get_data_hash.dig('upload_date'))
        # end

        test 'set data property (stored as json root value) with default_value does not overwrite original value' do
          data_set = DataCycleCore::TestPreparations.data_set_object('Bild')
          data_set.schema['properties']['upload_date']['default_value'] = Time.zone.now.beginning_of_day.to_s
          data_set.save

          data = { 'name' => 'Testbild', 'upload_date' => 2.days.ago.beginning_of_day }
          data_set.set_data_hash(data_hash: data, update_search_all: false)
          data_set.save

          assert_equal(2.days.ago.beginning_of_day, data_set.upload_date)
          assert_equal(2.days.ago.beginning_of_day, data_set.get_data_hash.dig('upload_date'))
        end

        # test 'set data property (stored as root translated_value) with default_value' do
        #   data_set = DataCycleCore::TestPreparations.data_set_object('Bild')
        #   data_set.schema['properties']['upload_date']['storage_location'] = 'translated_value'
        #   data_set.schema['properties']['upload_date']['default_value'] = Time.zone.now.beginning_of_day.to_s
        #   data_set.save

        #   data = { 'name' => 'Testbild' }
        #   data_set.set_data_hash(data_hash: data, update_search_all: false)
        #   data_set.save

        #   assert_equal(Time.zone.now.beginning_of_day, data_set.upload_date)
        #   assert_equal(Time.zone.now.beginning_of_day, data_set.get_data_hash.dig('upload_date'))
        # end

        test 'set data property (stored as root translated_value) with default_value does not overwrite original value' do
          data_set = DataCycleCore::TestPreparations.data_set_object('Bild')
          data_set.schema['properties']['upload_date']['storage_location'] = 'translated_value'
          data_set.schema['properties']['upload_date']['default_value'] = Time.zone.now.beginning_of_day.to_s
          data_set.save

          data = { 'name' => 'Testbild', 'upload_date' => 2.days.ago.beginning_of_day }
          data_set.set_data_hash(data_hash: data, update_search_all: false)
          data_set.save

          assert_equal(2.days.ago.beginning_of_day, data_set.upload_date)
          assert_equal(2.days.ago.beginning_of_day, data_set.get_data_hash.dig('upload_date'))
        end

        # test 'set data property (stored as object in value) with default_value' do
        #   data_set = DataCycleCore::TestPreparations.data_set_object('Artikel')
        #   data_set.schema['properties']['validity_period']['properties']['valid_from']['default_value'] = Time.zone.now.beginning_of_day.to_s
        #   data_set.save

        #   data = { 'name' => 'TestArtikel' }
        #   data_set.set_data_hash(data_hash: data, update_search_all: false)
        #   data_set.save

        #   assert_equal(Time.zone.now.beginning_of_day, data_set.validity_period.valid_from)
        #   assert_equal(Time.zone.now.beginning_of_day, data_set.get_data_hash.dig('validity_period', 'valid_from'))
        # end

        test 'set data property (stored as object in value) with default_value, does not overwrite original value' do
          data_set = DataCycleCore::TestPreparations.data_set_object('Artikel')
          data_set.schema['properties']['validity_period']['properties']['valid_from']['default_value'] = Time.zone.now.beginning_of_day.to_s
          data_set.save

          data = { 'name' => 'TestArtikel', 'validity_period' => { 'valid_from' => 2.days.ago.beginning_of_day } }
          data_set.set_data_hash(data_hash: data, update_search_all: false)
          data_set.save

          assert_equal(2.days.ago.beginning_of_day, data_set.validity_period.valid_from)
          assert_equal(2.days.ago.beginning_of_day, data_set.get_data_hash.dig('validity_period', 'valid_from'))
        end

        # test 'set data property (stored as object in translated_value) with default_value' do
        #   data_set = DataCycleCore::TestPreparations.data_set_object('Artikel')
        #   data_set.schema['properties']['validity_period']['properties']['valid_from']['default_value'] = Time.zone.now.beginning_of_day.to_s
        #   data_set.schema['properties']['validity_period']['storage_location'] = 'translated_value'
        #   data_set.schema['properties']['validity_period']['properties']['valid_from']['storage_location'] = 'translated_value'
        #   data_set.schema['properties']['validity_period']['properties']['valid_until']['storage_location'] = 'translated_value'
        #   data_set.save

        #   data = { 'name' => 'TestArtikel' }
        #   data_set.set_data_hash(data_hash: data, update_search_all: false)
        #   data_set.save

        #   assert_equal(Time.zone.now.beginning_of_day, data_set.validity_period.valid_from)
        #   assert_equal(Time.zone.now.beginning_of_day, data_set.get_data_hash.dig('validity_period', 'valid_from'))
        # end

        test 'set data property (stored as object in translated_value) with default_value, does not overwrite original data' do
          data_set = DataCycleCore::TestPreparations.data_set_object('Artikel')
          data_set.schema['properties']['validity_period']['properties']['valid_from']['default_value'] = Time.zone.now.beginning_of_day.to_s
          data_set.schema['properties']['validity_period']['storage_location'] = 'translated_value'
          data_set.schema['properties']['validity_period']['properties']['valid_from']['storage_location'] = 'translated_value'
          data_set.schema['properties']['validity_period']['properties']['valid_until']['storage_location'] = 'translated_value'
          data_set.save

          data = { 'name' => 'TestArtikel', 'validity_period' => { 'valid_from' => 2.days.ago.beginning_of_day } }
          data_set.set_data_hash(data_hash: data, update_search_all: false)
          data_set.save

          assert_equal(2.days.ago.beginning_of_day, data_set.validity_period.valid_from)
          assert_equal(2.days.ago.beginning_of_day, data_set.get_data_hash.dig('validity_period', 'valid_from'))
        end

        # test 'set data property (stored in column) with default_value' do
        #   data_set = DataCycleCore::TestPreparations.data_set_object('Bild')
        #   data_set.schema['properties']['description']['default_value'] = Time.zone.now.beginning_of_day.to_s
        #   data_set.save

        #   data = { 'name' => 'Testbild' }
        #   data_set.set_data_hash(data_hash: data, update_search_all: false)
        #   data_set.save

        #   assert_equal(Time.zone.now.beginning_of_day, data_set.description)
        #   assert_equal(Time.zone.now.beginning_of_day, data_set.get_data_hash.dig('description'))
        # end

        test 'set data property (stored in column) with default_value does not overwrite original data' do
          data_set = DataCycleCore::TestPreparations.data_set_object('Bild')
          data_set.schema['properties']['description']['default_value'] = Time.zone.now.beginning_of_day.to_s
          data_set.save

          data = { 'name' => 'Testbild', 'description' => 'Hallo' }
          data_set.set_data_hash(data_hash: data, update_search_all: false)
          data_set.save

          assert_equal('Hallo', data_set.description)
          assert_equal('Hallo', data_set.get_data_hash.dig('description'))
        end
      end
    end
  end
end
