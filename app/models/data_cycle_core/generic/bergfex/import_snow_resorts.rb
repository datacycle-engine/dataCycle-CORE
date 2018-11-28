# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Bergfex
      module ImportSnowResorts
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

        def self.find_snow_report(locale:, id:)
          snow_report_object = DataCycleCore::Generic::Collection2
          snow_report_type = Mongoid::PersistenceContext.new(snow_report_object, collection: 'snow_reports')
          snow_report_object.with(snow_report_type) do |mongo_item|
            item = mongo_item.where("dump.#{locale}.resort.id": id.to_s).sort("updated_at": -1)&.first
            item[:dump][locale] if item.present?
          end
        end

        def self.process_content(utility_object:, raw_data:, locale:, options:)
          I18n.with_locale(locale) do
            ['bergfex_status_icon'].each do |tag_name|
              DataCycleCore::Generic::Common::ImportTags.process_content(
                utility_object: utility_object,
                raw_data: raw_data,
                locale: locale,
                options: { import: utility_object.external_source.config.dig('import_config', tag_name)&.deep_symbolize_keys }
              )
            end
            report_data = find_snow_report(locale: locale, id: raw_data['id'])
            if report_data.present?
              report_data.delete('id')
              raw_data = raw_data.merge(report_data)
            end
            DataCycleCore::Generic::Bergfex::Processing.process_ski_resort(
              utility_object,
              raw_data,
              options.dig(:import, :transformations, :ski_resort),
              locale
            )
          end
        end
      end
    end
  end
end
