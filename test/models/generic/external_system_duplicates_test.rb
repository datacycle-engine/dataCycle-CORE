# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Generic
    class ExternalSystemDuplicatesTest < DataCycleCore::TestCases::ActiveSupportTestCase
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
        @external_source_f = DataCycleCore::ExternalSystem.find_by(name: 'Feratel')
        @external_source_oa = DataCycleCore::ExternalSystem.find_by(name: 'OutdoorActive')

        download_from_local_json(@external_source_f, 'feratel', true)
        download_from_local_json(@external_source_oa, 'outdoor_active')
        @external_source_f.import(@options)
        @external_source_oa.import(@options)
      end

      after(:all) do
        DataCycleCore::MongoHelper.drop_mongo_db('Feratel')
        DataCycleCore::MongoHelper.drop_mongo_db('OutdoorActive')
      end

      test 'perform import with duplicate image' do
        DataCycleCore::Thing.find_by(template: false, template_name: 'Bild', external_source_id: @external_source_oa.id, external_key: '3572986').destroy_content(save_history: false)
        duplicate = DataCycleCore::Thing.find_by(template: false, template_name: 'Bild', external_source_id: @external_source_f.id, external_key: '6fbe4b8f-e1c1-427e-8f82-a9911bed9d6f')
        duplicate.add_external_system_data(@external_source_oa, nil, nil, 'duplicate', '3572986')

        @external_source_oa.import(@options)
        assert_equal 2, DataCycleCore::Thing.find_by(template: false, template_name: 'POI', external_source_id: @external_source_f.id, external_key: '6f032432-f385-42e3-828f-00013377edf6').image.size
        assert_equal 1, DataCycleCore::Thing.find_by(template: false, template_name: 'Event', external_source_id: @external_source_f.id).image.size
        assert_equal 1, DataCycleCore::Thing.find_by(template: false, template_name: 'POI', external_source_id: @external_source_oa.id).image.size

        tour_images = DataCycleCore::Thing.find_by(template: false, template_name: 'Tour', external_source_id: @external_source_oa.id).image

        assert_equal 2, tour_images.size
        assert_equal ['18444221', duplicate.external_key], tour_images.pluck(:external_key) # the order of the array is important!
      end

      test 'perform import with duplicate poi' do
        DataCycleCore::Thing.find_by(template: false, template_name: 'POI', external_source_id: @external_source_oa.id, external_key: '3047464').destroy_content(save_history: false)
        DataCycleCore::Thing.find_by(template: false, template_name: 'POI', external_source_id: @external_source_f.id).add_external_system_data(@external_source_oa, nil, nil, 'duplicate', '3047464')
        @external_source_oa.import(@options)

        assert_equal 2, DataCycleCore::Thing.where(template: false, template_name: 'POI').with_schema_type('Place').size
        assert_equal 1, DataCycleCore::Thing.where(template: false, template_name: 'Unterkunft').with_schema_type('Place').size
        assert_equal 1, DataCycleCore::Thing.where(template: false, template_name: 'Event').with_schema_type('Event').size
        assert_equal 1, DataCycleCore::Thing.where(template: false, template_name: 'EventSchedule').with_schema_type('Event').size
        assert_equal 6, DataCycleCore::Thing.where(template: false, template_name: 'Bild').with_schema_type('CreativeWork').size
        assert_equal 1, DataCycleCore::Thing.where(template: false, template_name: 'Tour').with_schema_type('Place').size
      end

      test 'perform import and mark duplicate OutdoorActive POI as deleted (DeleteContentsSafe)' do
        external_key = '3047464'
        DataCycleCore::Thing.find_by(template: false, template_name: 'POI', external_source_id: @external_source_oa.id, external_key: external_key).destroy_content(save_history: false)
        content = DataCycleCore::Thing.find_by(template: false, template_name: 'POI', external_source_id: @external_source_f.id)
        content.add_external_system_data(@external_source_oa, nil, nil, 'duplicate', external_key)

        assert_equal 1, content.external_system_syncs.size
        assert_equal @external_source_f.id, content.external_source_id

        set_deleted_at(@external_source_oa, 'places', external_key)
        @external_source_oa.update(last_successful_download: Time.zone.now)
        @external_source_oa.import_single(:delete_places, @options)

        assert_equal 0, content.external_system_syncs.size
        assert_equal @external_source_f.id, content.reload.external_source_id

        set_deleted_at(@external_source_oa, 'places', external_key, nil)
      end

      test 'perform import and mark original OutdoorActive POI as deleted (DeleteContentsSafe)' do
        external_key = '6f032432-f385-42e3-828f-00013377edf6'
        DataCycleCore::Thing.find_by(template: false, template_name: 'POI', external_source_id: @external_source_f.id, external_key: external_key).destroy_content(save_history: false)
        content = DataCycleCore::Thing.find_by(template: false, template_name: 'POI', external_source_id: @external_source_oa.id)
        oa_external_key = content.external_key
        content.add_external_system_data(@external_source_f, nil, nil, 'duplicate', external_key)

        assert_equal 1, content.external_system_syncs.size
        assert_equal @external_source_oa.id, content.external_source_id

        set_deleted_at(@external_source_oa, 'places', oa_external_key)
        @external_source_oa.update(last_successful_download: Time.zone.now)
        @external_source_oa.import_single(:delete_places, @options)

        assert_equal 0, content.external_system_syncs.size
        assert_equal @external_source_f.id, content.reload.external_source_id

        set_deleted_at(@external_source_oa, 'places', oa_external_key, nil)
      end

      test 'perform import and mark duplicate feratel POI as deleted (DeleteContents)' do
        external_key = '6f032432-f385-42e3-828f-00013377edf6'
        DataCycleCore::Thing.find_by(template: false, template_name: 'POI', external_source_id: @external_source_f.id, external_key: external_key).destroy_content(save_history: false)
        content = DataCycleCore::Thing.find_by(template: false, template_name: 'POI', external_source_id: @external_source_oa.id)
        content.add_external_system_data(@external_source_f, nil, nil, 'duplicate', external_key)

        assert_equal 1, content.external_system_syncs.size
        assert_equal @external_source_oa.id, content.external_source_id

        set_deleted_at(@external_source_f, 'infrastructure_items', external_key)
        @external_source_f.update(last_successful_download: Time.zone.now)
        @external_source_f.import_single(:delete_infrastructures, @options)

        assert_equal 0, content.external_system_syncs.size
        assert_equal @external_source_oa.id, content.reload.external_source_id

        set_deleted_at(@external_source_f, 'infrastructure_items', external_key, nil)
      end

      test 'perform import and mark original feratel POI as deleted (DeleteContents)' do
        external_key = '3047464'
        DataCycleCore::Thing.find_by(template: false, template_name: 'POI', external_source_id: @external_source_oa.id, external_key: external_key).destroy_content(save_history: false)
        content = DataCycleCore::Thing.find_by(template: false, template_name: 'POI', external_source_id: @external_source_f.id, external_key: '6f032432-f385-42e3-828f-00013377edf6')
        f_external_key = content.external_key
        content.add_external_system_data(@external_source_oa, nil, nil, 'duplicate', external_key)

        assert_equal 1, content.external_system_syncs.size
        assert_equal @external_source_f.id, content.external_source_id

        set_deleted_at(@external_source_f, 'infrastructure_items', f_external_key)
        @external_source_f.update(last_successful_download: Time.zone.now)
        @external_source_f.import_single(:delete_infrastructures, @options)

        assert_equal 0, content.external_system_syncs.size
        assert_equal @external_source_oa.id, content.reload.external_source_id

        set_deleted_at(@external_source_f, 'infrastructure_items', f_external_key, nil)
      end

      private

      def set_deleted_at(external_system, collection_name, external_key, value = Time.zone.now)
        source_type = Mongoid::PersistenceContext.new(DataCycleCore::Generic::Collection, collection: collection_name)
        Mongoid.override_database("#{source_type.database_name}_#{external_system.id}")
        DataCycleCore::Generic::Collection.with(source_type) do |mongo_item|
          I18n.available_locales.each do |locale|
            mongo_item.where({
              "dump.#{locale}": { '$exists' => true },
              "external_id": external_key
            }).each do |item|
              if value.present?
                item.dump[locale.to_s]['deleted_at'] = value
              else
                item.dump[locale.to_s].delete('deleted_at')
              end
              item.save
            end
          end
        end

        Mongoid.override_database(nil)
      end
    end
  end
end
