# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Generic
    class HrsDestinationDataTest < ActiveSupport::TestCase
      def setup
        @cw_temp = DataCycleCore::Thing.where(template: false).count
      end

      def download_from_local_json(external_source)
        path = Rails.root.join('..', 'fixtures', 'external_sources', 'hrs_destination_data')
        files = path + '*.json'

        file_names = Dir[files]
        file_names.each do |file_name|
          file_base_name = File.basename(file_name, '.json')
          json_data = JSON.parse(File.read(file_name))

          download_config = external_source.config&.dig('download_config')&.symbolize_keys
          download_step = file_base_name.to_sym

          full_options = (external_source.default_options || {}).symbolize_keys.merge({ download: download_config.dig(download_step).symbolize_keys.except(:sorting) })
          locales = full_options[:locales] || full_options[:download][:locales] || I18n.available_locales
          download_object = DataCycleCore::Generic::DownloadObject.new(full_options.merge(external_source: external_source, locales: locales))
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

      test 'perform import' do
        options = {
          mode: 'full'
        }

        external_source = DataCycleCore::ExternalSystem.find_by(name: 'HRS destination-data')
        download_from_local_json(external_source)
        external_source.import(options)

        assert_equal(2, DataCycleCore::Thing.where(template: false, template_name: 'Event').with_schema_type('Event').count)
        assert_equal(2, DataCycleCore::Thing.where(template: false, template_name: 'Organization').with_schema_type('Organization').count)
        assert_equal(2, DataCycleCore::Thing.where(template: false, template_name: 'SubEvent').count)
        assert_equal(1, DataCycleCore::Thing.where(template: false, template_name: 'POI').with_schema_type('Place').count)
        assert_equal(1, DataCycleCore::Thing.where(template: false, template_name: 'Bild').with_schema_type('CreativeWork').count)
        assert_equal(16, DataCycleCore::ClassificationAlias.for_tree('HRS Destination Data - Classifications').count)

        # event only -> new_event_schedule, main item start_date, end_date are automatically set
        data = DataCycleCore::Thing.find_by(template: false, template_name: 'Event', name: 'In der Lobby')
        assert_equal(1, data.content_location.count)
        assert_equal(1, data.hrs_dd_categories.count)
        assert_equal(1, data.organizer.count)
        assert_equal(1, data.image.count)
        assert_equal(1, data.event_schedule.count)
        assert(data.start_date.present?)
        assert(data.end_date.present?)
        assert_equal(0, data.sub_event.count)

        # LEGACY: event more then once --> dates of subevent stored in event_schedule in array rdate
        data = DataCycleCore::Thing.find_by(template: false, template_name: 'Event', name: 'Offenes "Yoga Retreat" in Schwarzenberg')
        assert_equal(0, data.content_location.count)
        assert_equal(1, data.hrs_dd_categories.count)
        assert_equal(1, data.organizer.count)
        assert_equal(0, data.image.count)
        assert(data.start_date.present?)
        assert(data.end_date.present?)
        assert_equal(1, data.event_schedule.count)
        assert_equal(2, data.event_schedule.first.rdate.size)
        # LEGACY: event more then once --> event_period stored in separate SubEvents
        assert_equal(2, data.sub_event.count)
      end

      def teardown
        DataCycleCore::MongoHelper.drop_mongo_db('HRS destination-data')
      end
    end
  end
end
