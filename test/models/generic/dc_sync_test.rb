# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Generic
    class DcSyncTest < ActiveSupport::TestCase
      def setup
        @cw_temp = DataCycleCore::Thing.where(template: false).count
      end

      def download_from_local_json(external_source)
        path = Rails.root.join('..', 'fixtures', 'external_sources', 'dc_sync')
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
            DataCycleCore::Generic::Common::DownloadFunctions.download_test(
              download_object: download_object,
              data_id: id_function,
              data_name: name_function,
              raw_data: raw_data.dig('dump')
            )
          end
        end
      end

      test 'perform import' do
        options = {
          mode: 'full'
        }

        external_source = DataCycleCore::ExternalSystem.find_by(identifier: 'data-cycle-base')
        download_from_local_json(external_source)
        external_source.import(options)

        # pimcore Event
        assert_equal(
          ['Bild', 'Event', 'Organization', 'Örtlichkeit'],
          DataCycleCore::ExternalSystem.find_by(identifier: 'pimcore').things.pluck(:template_name).sort
        )

        event = DataCycleCore::ExternalSystem.find_by(identifier: 'pimcore').things.where(template_name: 'Event').first
        assert(event.present?)
        assert_equal('Abend Schneeschuhwanderung', event.name)
        schedule = event.event_schedule.first
        assert(event.event_schedule.first.present?)
        assert_equal(Time.new(2020, 12, 24, 16, 15).in_time_zone, schedule.schedule_object.first)
        assert_equal(Time.new(2021, 4, 8, 16, 15).in_time_zone, schedule.schedule_object.last)
        assert_equal(
          'Schneeschuhwandern-Montafon-Tourismus-Daniel-Zangerl-3.jpg',
          DataCycleCore::ExternalSystem.find_by(identifier: 'pimcore').things.where(template_name: 'Bild').first.name
        )
        assert_equal(external_source.identifier, event.external_source.identifier)
        assert_equal('pimcore', event.external_system_syncs.first.external_system.identifier)

        organization = DataCycleCore::ExternalSystem.find_by(identifier: 'pimcore').things.where(template_name: 'Organization').first
        assert_equal('Bergbahnen Gargellen', organization.name)
        assert_equal(external_source.identifier, organization.external_source.identifier)
        assert_equal('pimcore', organization.external_system_syncs.first.external_system.identifier)

        place = DataCycleCore::ExternalSystem.find_by(identifier: 'pimcore').things.where(template_name: 'Örtlichkeit').first
        assert_equal('Bergbahnen Gargellen', place.name)
        assert_equal(external_source.identifier, place.external_source.identifier)
        assert_equal('pimcore', place.external_system_syncs.first.external_system.identifier)

        # eyebase Bild:
        # image = DataCycleCore::ExternalSystem.find_by(name: 'Eyebase').things.first

        # outdooractive POI
        # DataCycleCore::ExternalSystem.find_by(identifier: 'outdooractive').things.first
      end

      def teardown
        DataCycleCore::MongoHelper.drop_mongo_db('data-cycle-base')
      end
    end
  end
end
