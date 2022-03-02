# frozen_string_literal: true

module DataCycleCore
  module Generic
    module IntermapsIski
      module Import
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
            lift_data = raw_data.dig('lifts', 'items')
            slope_data = raw_data.dig('slopes', 'items')

            DataCycleCore::Generic::IntermapsIski::Processing.process_ski_region(
              utility_object,
              raw_data,
              options.dig(:import, :transformations, :ski_resort)
            )

            lift_data.each do |lift|
              data = lift.merge({ 'snow_resort_id' => raw_data.dig('id') })
              DataCycleCore::Generic::IntermapsIski::Processing.process_lift(
                utility_object,
                data,
                options.dig(:import, :transformations, :lift)
              )
            end

            slope_data.each do |slope|
              data = slope.merge({ 'snow_resort_id' => raw_data.dig('id') })
              DataCycleCore::Generic::IntermapsIski::Processing.process_slope(
                utility_object,
                data,
                options.dig(:import, :transformations, :slope)
              )
            end
          end
        end
      end
    end
  end
end
