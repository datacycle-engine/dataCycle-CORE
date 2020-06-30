# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Generic
    class CelumTest < ActiveSupport::TestCase
      def setup
        @cw_temp = DataCycleCore::Thing.where(template: false).count
      end

      def download_from_local_json(external_source)
        path = Rails.root.join('..', 'fixtures', 'external_sources', 'celum')
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

        external_source = DataCycleCore::ExternalSystem.find_by(name: 'Celum')
        download_from_local_json(external_source)
        # patch external_source import_config because we do not want to download files
        external_source.config['import_config']['images']['transformations']['asset'] = external_source.config['import_config']['images']['transformations']['asset'].except('asset_type')
        external_source.config['import_config']['audio']['transformations']['asset'] = external_source.config['import_config']['audio']['transformations']['asset'].except('asset_type')
        external_source.config['import_config']['video']['transformations']['asset'] = external_source.config['import_config']['video']['transformations']['asset'].except('asset_type')

        external_source.import(options)

        assert_equal(2, DataCycleCore::Thing.where(template: false, template_name: 'Bild').with_schema_type('CreativeWork').count)
        assert_equal(1, DataCycleCore::Thing.where(template: false, template_name: 'Audio').with_schema_type('CreativeWork').count)
        assert_equal(1, DataCycleCore::Thing.where(template: false, template_name: 'Video').with_schema_type('CreativeWork').count)
        assert_equal(1, DataCycleCore::ClassificationAlias.for_tree('Celum - Keywords').count)
        assert_equal(1, DataCycleCore::ClassificationAlias.for_tree('Celum - Folders').count)
        assert_equal(1, DataCycleCore::ClassificationAlias.for_tree('Celum - Users').count)
      end

      def teardown
        DataCycleCore::MongoHelper.drop_mongo_db('Celum')
      end
    end
  end
end
