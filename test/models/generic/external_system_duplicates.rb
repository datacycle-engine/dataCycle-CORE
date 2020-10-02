# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Generic
    class FeratelTest < DataCycleCore::TestCases::ActiveSupportTestCase
      def download_from_local_json(external_source, folder_name, credentials = false)
        path = Rails.root.join('..', 'fixtures', 'external_sources', folder_name)
        files = path + '*.json'
        file_names = Dir[files]
        file_names.each do |file_name|
          file_base_name = File.basename(file_name, '.json')
          json_data = JSON.parse(File.read(file_name))

          download_config = external_source.config&.dig('download_config')&.symbolize_keys
          download_step = file_base_name.to_sym

          full_options = (external_source.default_options || {}).symbolize_keys.merge({ download: download_config.dig(download_step).symbolize_keys.except(:sorting) })
          locales = full_options[:locales] || full_options[:download][:locales] || I18n.available_locales
          download_object = DataCycleCore::Generic::DownloadObject.new(full_options.merge(external_source: external_source, locales: locales).merge(credentials ? { credentials: external_source.credentials&.first } : {}))
          id_function = full_options.dig(:download, :download_strategy).constantize.method(:data_id).to_proc
          name_function = full_options.dig(:download, :download_strategy).constantize.method(:data_name).to_proc

          json_data.each do |raw_data|
            DataCycleCore::Generic::Common::DownloadFunctions.download_single(
              download_object: download_object,
              data_id: id_function,
              data_name: name_function,
              modified: nil,
              raw_data: raw_data.dig('dump'),
              options: full_options.deep_symbolize_keys
            )
          end
        end
      end

      before(:all) do
        @options = {
          max_count: 1,
          mode: 'full'
        }
        @external_source_f = DataCycleCore::ExternalSystem.find_by(name: 'Feratel VCloud')
        @external_source_oa = DataCycleCore::ExternalSystem.find_by(name: 'OutdoorActive')

        download_from_local_json(@external_source_f, 'feratel', true)
        download_from_local_json(@external_source_oa, 'outdoor_active')
        @external_source_f.import(@options)
      end

      test 'perform import with duplicate image' do
        DataCycleCore::Thing.find_by(template: false, template_name: 'Bild', external_source_id: @external_source_f.id, external_key: 'd0e6eb3e-788a-421e-a240-5ac2d8bc082e').add_external_system_data(@external_source_oa, nil, nil, 'duplicate', '3572986')

        @external_source_oa.import(@options)

        assert_equal(2, DataCycleCore::Thing.where(template: false, template_name: 'POI').with_schema_type('Place').size)
        assert_equal(1, DataCycleCore::Thing.where(template: false, template_name: 'Unterkunft').with_schema_type('Place').size)
        assert_equal(1, DataCycleCore::Thing.where(template: false, template_name: 'Event').with_schema_type('Event').size)
        assert_equal(1, DataCycleCore::Thing.where(template: false, template_name: 'EventSchedule').with_schema_type('Event').size)
        assert_equal(5, DataCycleCore::Thing.where(template: false, template_name: 'Bild').with_schema_type('CreativeWork').size)
        assert_equal(1, DataCycleCore::Thing.where(template: false, template_name: 'Tour').with_schema_type('Place').size)

        assert_equal 2, DataCycleCore::Thing.find_by(template: false, template_name: 'POI', external_source_id: @external_source_f.id).image.size
        assert_equal 1, DataCycleCore::Thing.find_by(template: false, template_name: 'Event', external_source_id: @external_source_f.id).image.size
        assert_equal 2, DataCycleCore::Thing.find_by(template: false, template_name: 'POI', external_source_id: @external_source_oa.id).image.size
        assert_equal 1, DataCycleCore::Thing.find_by(template: false, template_name: 'Tour', external_source_id: @external_source_oa.id).image.size
      end

      test 'perform import with duplicate poi' do
        DataCycleCore::Thing.find_by(template: false, template_name: 'POI', external_source_id: @external_source_f.id).add_external_system_data(@external_source_oa, nil, nil, 'duplicate', '3047464')

        @external_source_oa.import(@options)

        assert_equal(1, DataCycleCore::Thing.where(template: false, template_name: 'POI').with_schema_type('Place').size)
        assert_equal(1, DataCycleCore::Thing.where(template: false, template_name: 'Unterkunft').with_schema_type('Place').size)
        assert_equal(1, DataCycleCore::Thing.where(template: false, template_name: 'Event').with_schema_type('Event').size)
        assert_equal(1, DataCycleCore::Thing.where(template: false, template_name: 'EventSchedule').with_schema_type('Event').size)
        assert_equal(6, DataCycleCore::Thing.where(template: false, template_name: 'Bild').with_schema_type('CreativeWork').size)
        assert_equal(1, DataCycleCore::Thing.where(template: false, template_name: 'Tour').with_schema_type('Place').size)
      end

      after(:all) do
        DataCycleCore::MongoHelper.drop_mongo_db('Feratel VCloud')
        DataCycleCore::MongoHelper.drop_mongo_db('OutdoorActive')
      end
    end
  end
end
