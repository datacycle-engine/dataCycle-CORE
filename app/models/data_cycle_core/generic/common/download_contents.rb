# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      module DownloadContents
        def self.download_content(utility_object:, options:)
          data_id_proc = proc do |data|
            data.dig(*options.dig(:download, :id_path).split('.'))
          end

          data_name_proc = proc do |data|
            data.dig(*options.dig(:download, :name_path).split('.'))
          end

          DataCycleCore::Generic::Common::DownloadFunctions.download_content(
            download_object: utility_object,
            data_id: data_id_proc,
            data_name: data_name_proc,
            options:
          )
        end
      end
    end
  end
end
