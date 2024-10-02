# frozen_string_literal: true

module DataCycleCore
  module Generic
    class DownloadObject < GenericObject
      TYPE = :download

      def read_type(opts = {})
        return if opts&.dig(:download, :read_type).blank?

        Mongoid::PersistenceContext.new(
          DataCycleCore::Generic::Collection,
          collection: opts.dig(:download, :read_type)
        )
      end

      def endpoint(opts = {})
        return if opts&.dig(:download, :endpoint).blank?

        changed_from = external_source.last_successful_download
        changed_from = nil if mode&.in?(['full', 'reset'])
        endpoint_options_params = opts.except(:download, :credentials, :external_source).merge({ changed_from: })
        endpoint_params = opts.dig(:credentials).symbolize_keys
          .merge(read_type: read_type(opts) || {})
          .merge(options: opts.dig(:download).merge(params: endpoint_options_params))

        opts.dig(:download, :endpoint).constantize.new(**endpoint_params)
      end
    end
  end
end
