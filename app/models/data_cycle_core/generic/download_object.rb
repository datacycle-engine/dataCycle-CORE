# frozen_string_literal: true

module DataCycleCore
  module Generic
    class DownloadObject
      attr_reader :external_source, :endpoint, :source_object, :source_type

      def initialize(**options)
        raise "Missing source_type for #{self.class}, options given: #{options}"       if options&.dig(:download, :source_type).blank?
        raise "Missing endpoint for #{self.class}, options given: #{options}"          if options&.dig(:download, :endpoint).blank?
        raise "Missing external_source for #{self.class}, options given: #{options}"   if options&.dig(:external_source).blank?

        @external_source = options[:external_source]
        @source_object = DataCycleCore::Generic::Collection
        @source_type = Mongoid::PersistenceContext.new(source_object, collection: options.dig(:download, :source_type))

        if options&.dig(:download, :read_type).present?
          read_type = { read_type: Mongoid::PersistenceContext.new(DataCycleCore::Generic::Collection, collection: options[:download][:read_type]) }
        else
          read_type = {}
        end
        @endpoint = options.dig(:download, :endpoint).constantize.new(options[:external_source].credentials.symbolize_keys.merge(read_type))
      end
    end
  end
end
