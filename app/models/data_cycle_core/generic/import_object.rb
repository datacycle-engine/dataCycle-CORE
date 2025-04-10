# frozen_string_literal: true

module DataCycleCore
  module Generic
    class ImportObject < GenericObject
      TYPE = :import

      attr_reader :logging, :history, :asset_download, :mode, :partial_update, :normalizer

      def initialize(**options)
        super

        @logging = @logger
        @history = @options[:history] || false
        no_asset_download = @options[:no_asset_download] || false
        @asset_download = !no_asset_download
        @partial_update = @options[:partial_update] || false
        @source_name = @options.dig(@type, :source_type)

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

      def source_steps_successful?
        # Check if all download steps of the source_type were successful
        external_source.source_steps_successful?(source_name, :download)
      end
    end
  end
end
