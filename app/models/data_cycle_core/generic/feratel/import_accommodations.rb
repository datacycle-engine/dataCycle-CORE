# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Feratel
      module ImportAccommodations
        def self.import_data(utility_object:, options:)
          DataCycleCore::Generic::Common::ImportFunctions.import_contents(
            utility_object: utility_object,
            iterator: method(:load_contents).to_proc,
            data_processor: method(:process_content).to_proc,
            options: options
          )
        end

        def self.load_contents(mongo_item, locale, source_filter)
          mongo_item.where({
            "dump.#{locale}": { '$exists': true },
            "dump.#{locale}.deleted_at": { '$exists': false }
          }.merge(source_filter.with_evaluated_values))
        end

        def self.process_content(utility_object:, raw_data:, locale:, options:)
          I18n.with_locale(locale) do
            return if raw_data.except(:Facilities).empty?

            ['feratel_owners'].each do |name_tag|
              DataCycleCore::Generic::Common::ImportTags.process_content(
                utility_object: utility_object,
                raw_data: raw_data,
                locale: locale,
                options: { import: utility_object.external_source.config.dig('import_config', name_tag).deep_symbolize_keys }
              )
            end

            DataCycleCore::Generic::Feratel::Processing.process_image(
              utility_object,
              raw_data,
              options.dig(:import, :transformations, :image)
            )

            Array.wrap(raw_data.dig('Addresses', 'Address')).each do |address_data|
              next unless address_data.dig('Type') == 'LandLord'

              if address_data.key?('Documents')
                DataCycleCore::Generic::Feratel::Processing.process_image(
                  utility_object,
                  address_data,
                  options.dig(:import, :transformations, :image)
                )
              end

              DataCycleCore::Generic::Feratel::Processing.process_landlord(
                utility_object,
                address_data,
                options.dig(:import, :transformations, :landlord)
              )
            end

            # to include rooms, services and pricing to accommodations
            # [raw_data.dig('Services', 'Service')]&.flatten&.compact&.each do |service_data|
            #   DataCycleCore::Generic::Feratel::Processing.process_room(
            #     utility_object,
            #     service_data,
            #     options.dig(:import, :transformations, :room)
            #   )
            # end
            #
            # [raw_data.dig('AdditionalServices', 'AdditionalService')]&.flatten&.compact&.each do |service_data|
            #   DataCycleCore::Generic::Feratel::Processing.process_additional_service(
            #     utility_object,
            #     service_data,
            #     options.dig(:import, :transformations, :room)
            #   )
            # end

            DataCycleCore::Generic::Feratel::Processing.process_accommodation(
              utility_object,
              raw_data,
              options.dig(:import, :transformations, :place)
            )
          end
        end
      end
    end
  end
end
