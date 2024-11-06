# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      class Webhook < DataCycleCore::Generic::WebhookBase
        def update(_data, _external_system)
          raise NotImplementedError
        end

        def create(_data, _external_system)
          raise NotImplementedError
        end

        def delete(_data, _external_system)
          raise NotImplementedError
        end

        def download_content(download_config:, data_name:, data:)
          return if download_config.blank? || data_name.blank? || data.blank?

          full_options = (external_source.default_options || {}).symbolize_keys.merge({ download: download_config[data_name].symbolize_keys.except(:sorting) })
          locales = full_options[:locales] || full_options.dig(:download, :locales) || I18n.available_locales
          download_object = DataCycleCore::Generic::DownloadObject.new(**full_options, external_source:, locales:)
          id_function = full_options.dig(:download, :download_strategy).constantize.method(:data_id).to_proc
          name_function = full_options.dig(:download, :download_strategy).constantize.method(:data_name).to_proc

          DataCycleCore::Generic::Common::DownloadFunctions.download_single(download_object:, data_id: id_function, data_name: name_function, raw_data: data, options: full_options.deep_symbolize_keys)
        end

        def import_content(import_config:, data_name:, data:, locale:)
          return if import_config.blank? || data_name.blank? || data.blank? || locale.blank?
          full_options = (external_source.default_options || {}).symbolize_keys.merge({ import: import_config[data_name].symbolize_keys.except(:sorting) })
          locales = full_options[:locales] || full_options[:import][:locales] || I18n.available_locales
          import_object = DataCycleCore::Generic::ImportObject.new(**full_options, external_source:, locales:)
          full_options.dig(:import, :import_strategy).constantize.process_content(utility_object: import_object, raw_data: data, locale:, options: full_options.deep_symbolize_keys)
        end
      end
    end
  end
end
