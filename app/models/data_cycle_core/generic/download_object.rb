# frozen_string_literal: true

module DataCycleCore
  module Generic
    class DownloadObject < GenericObject
      TYPE = :download
      FULL_MODES = ['full', 'reset'].freeze

      attr_accessor :item_cache

      def emtpy_item_cache
        self.item_cache = nil
      end

      def read_type(override_opts = {})
        opts = options.deep_merge(override_opts)
        return if opts&.dig(:download, :read_type).blank?

        Mongoid::PersistenceContext.new(
          DataCycleCore::Generic::Collection,
          collection: opts.dig(:download, :read_type)
        )
      end

      def read_type_collection(opts = {})
        read_type = read_type(opts)
        mongo_host = ENV['MONGODB_HOST']
        mongo_connection_string = "mongodb://#{mongo_host}:27017"

        Mongo::Client.new(mongo_connection_string, database: read_type)
      end

      def endpoint(override_opts = {})
        opts = options.deep_merge(override_opts)
        return if opts&.dig(:download, :endpoint).blank?

        changed_from = last_successful_try
        changed_from = nil if FULL_MODES.include?(mode.to_s)
        endpoint_options_params = opts.except(:download, :credentials, :external_source).merge(changed_from:)
        endpoint_params = opts[:credentials].symbolize_keys
          .merge(read_type: read_type(opts) || {})
          .merge(options: opts[:download].merge(params: endpoint_options_params))

        endpoint = opts.dig(:download, :endpoint).constantize.new(**endpoint_params)
        endpoint.instance_variable_set(:@download_object, self) unless endpoint.instance_variable_defined?(:@download_object)
        endpoint
      end
    end
  end
end
