# frozen_string_literal: true

module DataCycleCore
  module Generic
    module OutdoorActive
      module Processing
        def self.process_main_image(utility_object, raw_data, config)
          return if raw_data&.dig('primaryImage').nil?
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data.dig('primaryImage'),
            transformation: DataCycleCore::Generic::OutdoorActive::Transformations.outdoor_active_to_image(utility_object.external_source.id),
            default: { template: 'Bild' },
            config: config
          )
        end

        def self.process_image(utility_object, raw_data, config)
          template = config&.dig(:template) || 'Bild'

          (raw_data.dig('images', 'image') || []).each do |image_hash|
            process_copyright_holder(utility_object, image_hash.dig('meta', 'source'), config) if image_hash.dig('meta', 'source', 'id').present?
            process_fotograf(utility_object, image_hash.dig('meta', 'authorFull'), config) if image_hash.dig('meta', 'authorFull', 'id').present?
            DataCycleCore::Generic::Common::ImportFunctions.create_or_update_content(
              utility_object: utility_object,
              template: DataCycleCore::Generic::Common::ImportFunctions.load_template(template),
              data: DataCycleCore::Generic::Common::ImportFunctions.merge_default_values(
                config,
                DataCycleCore::Generic::OutdoorActive::Transformations
                .outdoor_active_to_image(utility_object.external_source.id)
                .call(image_hash)
              ).with_indifferent_access
            )
          end
        end

        def self.process_fotograf(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.create_or_update_content(
            utility_object: utility_object,
            template: DataCycleCore::Generic::Common::ImportFunctions.load_template('Organization'),
            data: DataCycleCore::Generic::Common::ImportFunctions.merge_default_values(
              config,
              DataCycleCore::Generic::OutdoorActive::Transformations.to_author.call(raw_data)
            ).with_indifferent_access
          )
        end

        def self.process_copyright_holder(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.create_or_update_content(
            utility_object: utility_object,
            template: DataCycleCore::Generic::Common::ImportFunctions.load_template('Organization'),
            data: DataCycleCore::Generic::Common::ImportFunctions.merge_default_values(
              config,
              DataCycleCore::Generic::OutdoorActive::Transformations.to_copyright_holder.call(raw_data)
            ).with_indifferent_access
          )
        end

        def self.process_tour(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::OutdoorActive::Transformations.outdoor_active_to_tour(utility_object.external_source.id),
            default: { template: 'Tour' },
            config: config
          )
        end

        def self.process_place(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::OutdoorActive::Transformations.outdoor_active_to_place(utility_object.external_source.id),
            default: { template: 'Örtlichkeit' },
            config: config
          )
        end
      end
    end
  end
end
