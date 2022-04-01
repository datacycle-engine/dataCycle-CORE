# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Feratel
      module ImportAdditionalServiceProviders
        def self.import_data(utility_object:, options:)
          DataCycleCore::Generic::Common::ImportFunctions.import_contents(
            utility_object: utility_object,
            iterator: method(:load_contents).to_proc,
            data_processor: method(:process_content).to_proc,
            options: options
          )
        end

        def self.load_contents(mongo_item, locale, source_filter)
          mongo_item.where({ "dump.#{locale}": { '$exists': true } }.merge(source_filter.with_evaluated_values))
        end

        def self.process_content(utility_object:, raw_data:, locale:, options:)
          I18n.with_locale(locale) do
            ['feratel_asp_owners'].each do |name_tag|
              DataCycleCore::Generic::Common::ImportTags.process_content(
                utility_object: utility_object,
                raw_data: raw_data,
                locale: locale,
                options: { import: utility_object.external_source.config.dig('import_config', name_tag).deep_symbolize_keys }
              )
            end

            Array.wrap(raw_data.dig('AdditionalServices', 'AdditionalService')).each do |service_data|
              DataCycleCore::Generic::Feratel::Processing.process_image(
                utility_object,
                service_data,
                options.dig(:import, :transformations, :image)
              )

              DataCycleCore::Generic::Feratel::Processing.process_meeting_point(
                utility_object,
                service_data.merge({ 'provider_id' => raw_data.dig('Id') }),
                options&.dig(:import, :transformations, :meeting_point)
              )

              DataCycleCore::Generic::Feratel::Processing.process_as(
                utility_object,
                service_data.merge({ 'provider_id' => raw_data.dig('Id') }),
                options&.dig(:import, :transformations, :additional_services)
              )
            end

            DataCycleCore::Generic::Feratel::Processing.process_asp(
              utility_object,
              raw_data,
              options&.dig(:import, :transformations, :additional_service_providers)
            )
          end
        end
      end
    end
  end
end
