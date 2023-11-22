# frozen_string_literal: true

module DataCycleCore
  module Generic
    class DownloadObject < GenericObject
      attr_reader :external_source, :options, :endpoint, :source_object, :source_type, :credentials

      def initialize(**options)
        raise "Missing source_type for #{self.class}, options given: #{options}"       if options&.dig(:download, :source_type).blank?
        raise "Missing external_source for #{self.class}, options given: #{options}"   if options&.dig(:external_source).blank?

        @options = options.with_indifferent_access
        @external_source = options[:external_source]
        @source_object = DataCycleCore::Generic::Collection
        @source_type = Mongoid::PersistenceContext.new(@source_object, collection: options.dig(:download, :source_type))
        @credentials = options.dig(:credentials) || options[:external_source].credentials
        changed_from = external_source.last_successful_download
        changed_from = nil if options.dig(:mode) == 'full'

        if options&.dig(:download, :read_type).present?
          read_type = { read_type: Mongoid::PersistenceContext.new(DataCycleCore::Generic::Collection, collection: options[:download][:read_type]) }
        else
          read_type = {}
        end

        return if options&.dig(:download, :endpoint).blank? # for mark_deleted_from_data tasks
        endpoint_options_params = options.except(:download, :credentials, :external_source).merge({ changed_from: })
        endpoint_params = @credentials.symbolize_keys
          .merge(read_type)
          .merge(options: options.dig(:download).merge(params: endpoint_options_params))
        @endpoint = options.dig(:download, :endpoint).constantize.new(**endpoint_params)
      end
    end
  end
end
