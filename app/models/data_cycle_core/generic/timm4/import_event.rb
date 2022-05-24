# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Timm4
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
          mongo_item.where(source_filter.with_evaluated_values.merge("dump.#{locale}": { '$exists' => true }))
        end

        def self.process_content(utility_object:, raw_data:, locale:, options:)
          I18n.with_locale(locale) do
            [raw_data['mainImage'], raw_data['headerImage'], *raw_data['images']].compact.each do |image_data|
              data =
                if image_data.is_a?(::String)
                  { 'content_url' => image_data }
                elsif image_data.is_a?(::Hash)
                  image_data.merge({ 'content_url' => image_data['url'] })
                end

              if data.dig('photographer').present?
                DataCycleCore::Generic::Timm4::Processing.process_author(
                  utility_object,
                  { 'name' => data.dig('photographer') },
                  options.dig(:import, :transformations, :author)
                )
              end

              if data.dig('copyright').present?
                DataCycleCore::Generic::Timm4::Processing.process_copyright_holder(
                  utility_object,
                  { 'name' => data.dig('copyright') },
                  options.dig(:import, :transformations, :copyright_holder)
                )
              end

              DataCycleCore::Generic::Timm4::Processing.process_image(
                utility_object,
                data,
                options.dig(:import, :transformations, :image)
              )
            end

            if raw_data['organizer'].present?
              DataCycleCore::Generic::Timm4::Processing.process_organizer(
                utility_object,
                raw_data['organizer'],
                options.dig(:import, :transformations, :organizer)
              )
            end

            if raw_data['address'].present?
              DataCycleCore::Generic::Timm4::Processing.process_event_location(
                utility_object,
                raw_data['address'],
                options.dig(:import, :transformations, :place)
              )
            end

            DataCycleCore::Generic::Timm4::Processing.process_event(
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
