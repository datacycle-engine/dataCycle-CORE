# frozen_string_literal: true

module DataCycleCore
  module Generic
    class DownloadObject
      attr_reader :external_source, :endpoint, :logging, :source_object, :source_type

      def initialize(**options)
        if options&.dig(:download, :logging_strategy).blank?
          @logging = DataCycleCore::Generic::Logger::Console.new('download')
        else
          @logging = instance_eval(options.dig(:download, :logging_strategy))
        end

        raise "Missing source_type for #{self.class}, options given: #{options}"       if options&.dig(:download, :source_type).blank?
        raise "Missing endpoint for #{self.class}, options given: #{options}"          if options&.dig(:download, :endpoint).blank?
        raise "Missing download_strategy for #{self.class}, options given: #{options}" if options&.dig(:download, :download_strategy).blank?
        raise "Missing external_source for #{self.class}, options given: #{options}"   if options&.dig(:external_source).blank?

        @external_source = options[:external_source]
        @source_object = DataCycleCore::Generic::Collection
        @source_type = Mongoid::PersistenceContext.new(source_object, collection: options.dig(:download, :source_type))
        @endpoint = options.dig(:download, :endpoint).constantize.new(options[:external_source].credentials.symbolize_keys)
      ensure
        logging.close if logging.respond_to?(:close)
      end
    end
  end
end
