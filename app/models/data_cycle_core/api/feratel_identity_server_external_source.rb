# frozen_string_literal: true

module DataCycleCore
  module Api
    class FeratelIdentityServerExternalSource < DataCycleCore::Api::GenericExternalSource
      def update(data)
        download_config = external_source.config&.dig('download_config')&.symbolize_keys
        import_config = external_source.config&.dig('import_config')&.symbolize_keys

        processed_items = []

        download_content(download_config: download_config, data_name: :users, data: data)

        data.each do |object|
          processed_items << import_content(import_config: import_config, data_name: :users, data: object, locale: 'de')
        end
        processed_items
      end

      def create(data)
        update(data)
      end
    end
  end
end