# frozen_string_literal: true

module DataCycleCore
  module Generic
    module DestinationOne
      module ImportEvent
        def self.import_data(utility_object:, options:)
          DataCycleCore::Generic::Common::ImportFunctions.import_contents(
            utility_object: utility_object,
            iterator: method(:load_contents).to_proc,
            data_processor: method(:process_content).to_proc,
            options: options
          )
        end

        def self.load_contents(mongo_item, locale, source_filter)
          mongo_item.where(
            I18n.with_locale(locale) { source_filter.with_evaluated_values }
              .merge(
                "dump.#{locale}": { '$exists': true },
                "dump.#{locale}.deleted_at": { '$exists': false }
              )
          )
        end

        def self.process_content(utility_object:, raw_data:, locale:, options:)
          return if raw_data.blank?

          I18n.with_locale(locale) do
            if raw_data.dig('media_objects').present?
              Array.wrap(raw_data.dig('media_objects'))
                .select { |i| i.dig('rel').in?(['default', 'imagegallery']) } # for images
                .each do |image_data|
                DataCycleCore::Generic::DestinationOne::Processing.process_image(
                  utility_object,
                  image_data,
                  options.dig(:import, :transformations, :image)
                )
              end
            end

            if raw_data.dig('addresses').present?
              data = Array.wrap(raw_data.dig('addresses')).detect { |i| i.dig('rel').in?(['organizer']) }
              if data.present?
                DataCycleCore::Generic::DestinationOne::Processing.process_organizer(
                  utility_object,
                  data.merge({ 'id' => raw_data.dig('id') }),
                  options.dig(:import, :transformations, :organizer)
                )
              end
            end

            DataCycleCore::Generic::DestinationOne::Processing.process_content_location(
              utility_object,
              raw_data,
              options.dig(:import, :transformations, :place)
            )

            DataCycleCore::Generic::DestinationOne::Processing.process_event(
              utility_object,
              raw_data,
              options.dig(:import, :transformations, :event)
            )
          end
        end
      end
    end
  end
end
