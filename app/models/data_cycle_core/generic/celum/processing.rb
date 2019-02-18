# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Celum
      module Processing
        def self.process_images(utility_object, raw_data, config)
          remote_file_url = [
            utility_object.external_source.credentials.dig('host'),
            'download.api?username=',
            utility_object.external_source.credentials.dig('user'),
            '&password=',
            utility_object.external_source.credentials.dig('password'),
            '&documentId=',
            raw_data.dig('id', '#cdata-section')
          ].join('')

          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data.merge(remote_file_url: remote_file_url),
            transformation: DataCycleCore::Generic::Celum::Transformations.document_to_bild(utility_object.external_source.id),
            default: { template: 'Bild' },
            config: config
          )
        end
      end
    end
  end
end
