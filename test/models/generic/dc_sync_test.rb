# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Generic
    class DcSyncTest < ActiveSupport::TestCase
      def setup
        @cw_temp = DataCycleCore::Thing.where(template: false).count
        options = {
          mode: 'full'
        }

        # import a event to be from feratel
        event = DataCycleCore::DummyDataHelper.create_data('event')
        event.external_source_id = DataCycleCore::ExternalSystem.find_by(identifier: 'Feratel').id
        event.external_key = '00000000-0000-0000-0000-000000000005'
        event.save

        external_source = DataCycleCore::ExternalSystem.find_by(identifier: 'data-cycle-base')
        download_from_local_json(external_source)
        external_source.import(options)
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
            DataCycleCore::Generic::Common::DownloadFunctions.dump_test_data(
              download_object: download_object,
              data_id: id_function,
              data_name: name_function,
              raw_data: raw_data.dig('dump')
            )
          end
        end
      end

      test 'perform import' do
        external_source = DataCycleCore::ExternalSystem.find_by(identifier: 'data-cycle-base')
        # pimcore Event
        assert_equal(
          ['Bild', 'Bild', 'Event', 'Organization', 'Örtlichkeit'],
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
          ['Adventfenster.JPG', 'Schneeschuhwandern-Montafon-Tourismus-Daniel-Zangerl-3.jpg'],
          DataCycleCore::ExternalSystem.find_by(identifier: 'pimcore').things.where(template_name: 'Bild').pluck(:name).sort
        )
        assert_equal(external_source.identifier, event.external_source.identifier)
        assert_equal('pimcore', event.external_system_syncs.first.external_system.identifier)

        # embedded are there
        assert_equal('Virtuell', event.virtual_location.first.name)
        assert_equal('https://virtuell.at', event.virtual_location.first.url)
        assert_equal('test', event.additional_information.first.name)
        assert_equal('<p>Das ist ein Test.</p>', event.additional_information.first.description)
        assert_equal(1, event.additional_information.first.image.size)

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

      test 'import trivial event originally imported from outdooractive' do
        event = DataCycleCore::Thing.find_by(external_key: '00000000-0000-0000-0000-000000000001')
        assert_equal('test_data1', event.name)
        assert_equal('00000000-0000-0000-0000-000000000001', event.external_key)
        assert_equal('DataCycle Basic', event.external_source.name)
        assert_equal('outdooractive', event.external_systems.first.identifier)
        assert_equal('duplicate', event.external_system_syncs.first.sync_type)
        assert_equal('00000000-0000-0000-0000-000000000001', event.external_system_syncs.first.external_key)
      end

      test 'trivial event imported from outdooractive, imported from feratel' do
        event = DataCycleCore::Thing.find_by(external_key: '00000000-0000-0000-0000-000000000002')
        assert_equal('test_data1', event.name)
        assert_equal('00000000-0000-0000-0000-000000000002', event.external_key)
        assert_equal('DataCycle Basic', event.external_source.name)
        assert_equal(2, event.external_systems.size)
        assert_equal(['feratel', 'outdooractive'], event.external_systems.pluck(:identifier).sort)

        outdooractive = DataCycleCore::ExternalSystem.find_by(identifier: 'outdooractive')
        oa_sync_data = event.external_system_syncs.find_by(external_system_id: outdooractive.id)
        assert_equal('duplicate', oa_sync_data.sync_type)
        assert_equal('success', oa_sync_data.status)
        assert_equal('00000000-0000-0000-0000-000000000002', oa_sync_data.external_key)

        feratel = DataCycleCore::ExternalSystem.find_by(identifier: 'feratel')
        feratel_sync_data = event.external_system_syncs.find_by(external_system_id: feratel.id)
        assert_equal('import', feratel_sync_data.sync_type)
        assert_equal('success', feratel_sync_data.status)
        assert_equal('00000000-0000-0000-0000-000000000003', feratel_sync_data.external_key)
      end

      test 'trivial event with classification' do
        event = DataCycleCore::Thing.find_by(external_key: '00000000-0000-0000-0000-000000000004')
        assert_equal('test_data_classification', event.name)

        # check that no new external_systems have been created
        assert_equal(1, ExternalSystem.where(identifier: 'outdooractive').count)
        assert_equal(1, ExternalSystem.where(identifier: 'feratel').count)
        # check that new external_system is created
        assert_equal(1, ExternalSystem.where(identifier: 'test_external_source').count)

        # uses classification locally when present
        assert_equal('Veranstaltung', event.data_type.first.name)
        assert_equal(1, event.data_type.first.classification_aliases.size)
        assert_equal('Inhaltstypen', event.data_type.first.primary_classification_alias.classification_tree_label.name)

        # generates entries for locally new classifications (classification_attribute known)
        assert_equal(1, event.feratel_facilities_events.size)
        assert_equal('Diverse Veranstaltungen/Feste', event.feratel_facilities_events.first.name)
        assert_equal(1, event.feratel_facilities_events.first.classification_aliases.size)
        assert_equal('Feratel - Merkmale - Events', event.feratel_facilities_events.first.primary_classification_alias.classification_tree_label.name)

        # generate entries for a lokally unknown classification where attribute does not iexist in event template
        assert(event.classifications.pluck(:name).include?('Bergerlebnis'))
        classification = event.classifications.where(name: 'Bergerlebnis').first
        assert_equal(1, classification.classification_aliases.size)
        assert_equal('Pimcore - Tags', classification.primary_classification_alias.classification_tree_label.name)

        # generates a new classification with a formerly unknown external_system
        assert(event.classifications.find_by(name: 'Classification Test System').present?)
        classification = event.classifications.find_by(name: 'Classification Test System')
        assert_equal('test_external_source', classification.external_source.name)
        assert_equal('test_external_source', classification.external_source.identifier)
        assert_equal('universal_classifications', classification.classification_contents.first.relation)
        assert_equal(1, classification.classification_aliases.size)
        assert_equal('Test Tree', classification.primary_classification_alias.classification_tree_label.name)
      end

      test 'imported data successfully recognizes already present data from feratel' do
        event = DataCycleCore::Thing.find_by(external_key: '00000000-0000-0000-0000-000000000005')
        assert_equal('Feratel', event.external_source.identifier)

        assert_equal(2, event.external_system_syncs.count)
        assert_equal(['data-cycle-base', 'outdooractive'], event.external_system_syncs.map(&:external_system).map(&:identifier).sort)
        assert_equal('00000000-0000-0000-0000-000000000005', event.external_system_syncs.pluck(:external_key).uniq.first)

        assert_equal('Headline', event.name) # make sure the event itself is unchanged by the synced data
      end

      def teardown
        DataCycleCore::MongoHelper.drop_mongo_db('data-cycle-base')
      end
    end
  end
end
