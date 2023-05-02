# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      module Transformations
        module AdditionalInformation
          def self.add_info(data, external_source_id)
            data.map { |text|
              if text['type_of_info'].present?
                text = DataCycleCore::Generic::Common::DataReferenceTransformations
                  .add_classification_name_references(text, 'type_of_information', 'Informationstypen', 'type_of_info')
              end
              text = DataCycleCore::Generic::Common::DataReferenceTransformations
                .add_classification_name_references(text, 'universal_classifications', 'Externe Informationstypen', 'type')
              text = DataCycleCore::Generic::Common::DataReferenceTransformations
                .add_external_content_references(text, 'id', external_source_id, ['external_key'])
              text['id'] = text['id'].first
              text
            }.compact
          end
        end
      end
    end
  end
end
