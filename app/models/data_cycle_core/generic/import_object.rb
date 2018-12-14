# frozen_string_literal: true

module DataCycleCore
  module Generic
    class ImportObject < GenericObject
      attr_reader :external_source, :options, :locales, :logging, :source_type, :source_object, :mode, :history, :normalizer
      attr_writer :mode

      def initialize(**options)
        raise "Missing external_source for #{self.class}, options given: #{options}" if options[:external_source].blank?
        raise "Missing source_type for #{self.class}, options given: #{options}"     if options[:import][:source_type].nil?

        @external_source = options[:external_source]
        @options = options.with_indifferent_access

        if DataCycleCore::Feature::Normalize.enabled?
          normalize_logger = DataCycleCore::Generic::Logger::LogFile.new('normalize')
          external_source = DataCycleCore::ExternalSource.find_by(name: DataCycleCore.features.dig(:normalize, :external_source))
          @normalizer = DataCycleCore::MasterData::NormalizeData.new(logger: normalize_logger, host: external_source.credentials.dig('host'), end_point: external_source.credentials.dig('end_point'))
        end
        @source_object = DataCycleCore::Generic::Collection
        @source_type = Mongoid::PersistenceContext.new(@source_object, collection: options[:import][:source_type])
        @locales = options[:locales]
        @logging = init_logging(:import)
        @history = options.dig(:history) || false
        @mode = options.dig(:import, :mode)&.to_sym || options.dig(:mode)&.to_sym || :incremental
      end
    end
  end
end
