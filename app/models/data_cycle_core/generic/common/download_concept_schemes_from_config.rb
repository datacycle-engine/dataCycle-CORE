# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      module DownloadConceptSchemesFromConfig
        def self.download_content(utility_object:, options:)
          DataCycleCore::Generic::Common::DownloadFunctions.download_content(
            download_object: utility_object,
            iterator: method(:load_concept_schemes_from_config).to_proc,
            data_id: method(:data_id).to_proc,
            data_name: method(:data_name).to_proc,
            options:,
            iterate_credentials: false
          )
        end

        def self.load_concept_schemes_from_config(options:, **)
          Array.wrap(options.dig(:download, :tree_label)).map do |label|
            { 'id' => label, 'name' => label }
          end
        end

        def self.data_id(data)
          data.dig('id')
        end

        def self.data_name(data)
          data.dig('name')
        end
      end
    end
  end
end
