# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Feratel
      module Processing
        def self.process_image(utility_object, raw_data, config)
          type = config&.dig(:content_type)&.constantize || DataCycleCore::CreativeWork
          template = config&.dig(:template) || 'Bild'

          ([raw_data.dig('Documents', 'Document')].flatten.reject(&:nil?).select { |d|
            d['Class'] == 'Image'
          }.each do |image_hash|
            DataCycleCore::Generic::Common::ImportFunctions.create_or_update_content(
              utility_object: utility_object,
              class_type: type,
              template: DataCycleCore::Generic::Common::ImportFunctions.load_template(type, template),
              data: DataCycleCore::Generic::Common::ImportFunctions.merge_default_values(
                config,
                DataCycleCore::Generic::Feratel::Transformations
                .feratel_to_image
                .call(image_hash)
              ).with_indifferent_access
            )
          end
          )
        end

        def self.process_accommodation(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::Feratel::Transformations.feratel_to_accommodation(utility_object.external_source.id),
            default: { content_type: DataCycleCore::Place, template: 'Unterkunft' },
            config: config
          )
        end
      end
    end
  end
end
