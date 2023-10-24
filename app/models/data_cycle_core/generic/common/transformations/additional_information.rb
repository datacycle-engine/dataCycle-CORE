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

          def self.add_description_to_additional_informations(data, external_source_id, importer_name)
            add_description_to_additional_information_types(data, external_source_id, importer_name, ['description'])
          end

          def self.add_description_to_additional_information_types(data, external_source_id, importer_name, types)
            return data if types.blank?
            return data if data['external_key'].blank?

            additional_information = []
            Array.wrap(types).each do |type|
              additional_information << {
                'type' => type,
                'type_of_info' => type,
                'name' => I18n.t("import.generic.#{type}", default: [type]),
                'external_key' => "#{importer_name} - AdditionalInformation - #{data.dig('external_key')} - #{type}",
                'description' => data[type]
              }
            end

            return data if additional_information.blank?

            data['additional_information'] = DataCycleCore::Generic::Common::Transformations::AdditionalInformation.add_info(additional_information, external_source_id)
            data
          end
        end
      end
    end
  end
end
