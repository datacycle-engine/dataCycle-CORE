# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      # Import strategy that only syncs external system data (ExternalSystemSync) to existing
      # Thing objects, without creating or updating the contents themselves.
      #
      # Uses ImportFunctions.process_syncs instead of ImportFunctions.process_step.
      # The step configuration (template, transformation, data, ...) lives directly
      # on the import root layer, nested_contents and data_filter are not supported.
      # As syncs are not translated, only the first configured locale is imported.
      module ImportSyncs
        extend DataCycleCore::Generic::Common::Transformations::TransformationUtilities

        # Entry point for the import strategy.
        #
        # @param utility_object [Object] the import utility object
        # @param options [Hash] the import step options
        def self.import_data(utility_object:, options:)
          utility_object.locales = utility_object.locales.first(1)

          DataCycleCore::Generic::Common::ImportFunctions.import_contents(
            utility_object:,
            iterator: method(:load_contents).to_proc,
            data_processor: method(:process_content).to_proc,
            options:
          )
        end

        # Loads the raw contents to process from the download source.
        #
        # @param filter_object [DataCycleCore::Generic::Common::Import::FilterObject] the source filter
        # @return [Mongoid::Criteria] the filtered query
        def self.load_contents(filter_object:)
          filter_object.with_locale.without_deleted.query
        end

        # Transforms a single raw content item and syncs its external system data to an existing Thing.
        #
        # @param utility_object [Object] the import utility object
        # @param raw_data [Hash] the raw data from the external system
        # @param locale [String, Symbol] the locale to process
        # @param options [Hash] the import step options
        # @return [DataCycleCore::Thing, nil] the synced Thing, or nil if not found
        def self.process_content(utility_object:, raw_data:, locale:, options:)
          I18n.with_locale(locale) do
            raw_data = raw_data.merge(options.dig(:import, :data)) if options.dig(:import, :data).present?

            return if DataCycleCore::DataHashService.deep_blank?(raw_data)
            return if raw_data.keys.size == 1 && raw_data.keys.first.in?(['id', '@id'])

            transformation_method = options[:transformations].constantize.method(options.dig(:import, :transformation))
            config = options[:import].except(:template, :transformation)
            transformation = transformation_with_args(transformation_method:, utility_object:, config:)

            DataCycleCore::Generic::Common::ImportFunctions.process_syncs(
              utility_object:,
              raw_data:,
              transformation:,
              default: { template: options.dig(:import, :template) },
              config: utility_object.step_config(config)
            )
          end
        end
      end
    end
  end
end
