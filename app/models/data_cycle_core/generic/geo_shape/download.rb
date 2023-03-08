# frozen_string_literal: true

module DataCycleCore
  module Generic
    module GeoShape
      module Download
        def self.download_content(utility_object:, options:)
          DataCycleCore::Generic::Common::DownloadFunctions.download_data(
            download_object: utility_object,
            data_id: method(:data_id).to_proc.curry[options.dig(:download, :tag_id_path)],
            data_name: method(:data_name).to_proc.curry[options.dig(:download, :tag_name_path)],
            modified: method(:modified).to_proc.curry[options.dig(:download, :tag_modified_path)],
            options: options
          )
        end

        def self.data_id(path, data)
          data.dig(path || 'id')
        end

        def self.data_name(path, data)
          data.dig(path || 'name')
        end

        def self.modified(path, data)
          data.dig(path || 'updated_at')
        end
      end
    end
  end
end
