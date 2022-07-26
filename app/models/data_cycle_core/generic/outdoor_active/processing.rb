# frozen_string_literal: true

module DataCycleCore
  module Generic
    module OutdoorActive
      module Processing
        def self.process_image(utility_object, raw_data, config)
          template = config&.dig(:template) || 'Bild'

          (raw_data.dig('images', 'image') || []).each do |image_hash|
            process_copyright_holder(utility_object, image_hash, config)
            process_fotograf(utility_object, image_hash, config)

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
          # parse fallbacks ...
          author_data = DataCycleCore::Generic::OutdoorActive::Transformations.to_author.call(raw_data)

          return if author_data.blank?

          DataCycleCore::Generic::Common::ImportFunctions.create_or_update_content(
            utility_object: utility_object,
            template: DataCycleCore::Generic::Common::ImportFunctions.load_template('Organization'),
            data: DataCycleCore::Generic::Common::ImportFunctions.merge_default_values(
              config,
              author_data
            ).with_indifferent_access
          )
        end

        def self.process_copyright_holder(utility_object, raw_data, config)
          copyright_data = get_copyright_holder(raw_data)
          return if copyright_data.blank?

          DataCycleCore::Generic::Common::ImportFunctions.create_or_update_content(
            utility_object: utility_object,
            template: DataCycleCore::Generic::Common::ImportFunctions.load_template('Organization'),
            data: DataCycleCore::Generic::Common::ImportFunctions.merge_default_values(
              config,
              DataCycleCore::Generic::OutdoorActive::Transformations.to_copyright_holder.call(copyright_data)
            ).with_indifferent_access
          )
        end

        def self.get_copyright_holder(data)
          if data.dig('meta', 'source', 'id').present? && data.dig('meta', 'source', 'name').present?
            {
              'name' => data.dig('meta', 'source', 'name'),
              'external_key' => data.dig('meta', 'source', 'id')
            }
          elsif data.dig('meta', 'source', 'name').present?
            {
              'name' => data.dig('meta', 'source', 'name'),
              'external_key' => Digest::MD5.new.update(data.dig('meta', 'source', 'name')).hexdigest
            }
          else
            {}
          end
        end

        def self.process_author(utility_object, raw_data, _config)
          author_data = DataCycleCore::Generic::OutdoorActive::Transformations.to_author.call(raw_data)

          return if author_data.blank?

          DataCycleCore::Generic::Common::ImportFunctions.create_or_update_content(
            utility_object: utility_object,
            template: DataCycleCore::Generic::Common::ImportFunctions.load_template('Organization'),
            data: author_data.with_indifferent_access
          )
        end

        def self.process_publisher(utility_object, raw_data, _config)
          publisher_data = DataCycleCore::Generic::OutdoorActive::Transformations.to_publisher.call(raw_data)

          return if publisher_data.blank?

          DataCycleCore::Generic::Common::ImportFunctions.create_or_update_content(
            utility_object: utility_object,
            template: DataCycleCore::Generic::Common::ImportFunctions.load_template('Organization'),
            data: publisher_data.with_indifferent_access
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
