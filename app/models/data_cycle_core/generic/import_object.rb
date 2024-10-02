# frozen_string_literal: true

module DataCycleCore
  module Generic
    class ImportObject < GenericObject
      TYPE = :import

      attr_reader :logging, :history, :asset_download, :mode, :partial_update, :normalizer

      def initialize(**options)
        super(**options)

        @logging = @logger
        @history = @options.dig(:history) || false
        no_asset_download = @options.dig(:no_asset_download) || false
        @asset_download = !no_asset_download
        @partial_update = @options.dig(:partial_update) || false

        @concepts_cache = {}
      end

      def concepts_by_path(paths)
        Array.wrap(paths).each do |p|
          @concepts_cache[p] ||= DataCycleCore::Concept.by_full_paths(p)
        end

        Array.wrap(paths).map { |p| @concepts_cache[p] }
      end

      def concept_by_path(path)
        concepts_by_path(path).first
      end
    end
  end
end
