# frozen_string_literal: true

module DataCycleCore
  module Generic
    class ImportObject < GenericObject
      attr_reader :external_source, :options, :locales, :logging, :source_type, :source_object, :mode, :history, :partial_update, :normalizer, :asset_download
      attr_writer :mode

      def initialize(**options)
        raise "Missing external_source for #{self.class}, options given: #{options}" if options[:external_source].blank?
        raise "Missing source_type for #{self.class}, options given: #{options}"     if options[:import][:source_type].nil?

        @external_source = options[:external_source]
        @options = options.with_indifferent_access

        if DataCycleCore::Feature::Normalize.enabled?
          normalize_logger = DataCycleCore::Generic::Logger::LogFile.new('normalize')
          external_source = DataCycleCore::ExternalSystem.find_by(name: DataCycleCore.features.dig(:normalize, :external_source))
          @normalizer = DataCycleCore::MasterData::NormalizeData.new(logger: normalize_logger, host: external_source.credentials.dig('host'), end_point: external_source.credentials.dig('end_point'))
        end
        @source_object = DataCycleCore::Generic::Collection
        @source_type = Mongoid::PersistenceContext.new(@source_object, collection: options[:import][:source_type])
        @locales = options[:locales]
        @logging = init_logging(:import)
        @history = options.dig(:history) || false
        no_asset_download = options.dig(:no_asset_download) || false
        @asset_download = !no_asset_download
        @mode = options.dig(:import, :mode)&.to_sym || options.dig(:mode)&.to_sym || :incremental
        @partial_update = options.dig(:partial_update) || false
      end

      def self.concepts_cache
        @concepts_cache ||= {}
      end

      def concepts_by_path(paths)
        Array.wrap(paths).each do |p|
          self.class.concepts_cache[p] ||= DataCycleCore::Concept.by_full_paths(p)
        end
        Array.wrap(paths).map { |p| self.class.concepts_cache[p] }
      end

      def concept_by_path(path)
        concepts_by_path(path).first
      end
    end
  end
end
