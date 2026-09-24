# frozen_string_literal: true

module DataCycleCore
  module Generic
    class ImportObject < GenericObject
      TYPE = :import
      # Modes that process only the mongo documents the download actually changed; see
      # DownloadObject::FULL_MODES for why +full_delta+ appears in both lists.
      DELTA_MODES = ['incremental', 'full_delta'].freeze
      DEFAULT_CONFIG_KEYS = [
        'import_external_system_data',
        'reject_unknown_external_systems',
        'primary_system_priority',
        'current_instance_identifiers',
        'external_system_identifier_mapping',
        'external_system_identifier_transformation',
        'invalidate_related_cache'
      ].freeze

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

      # The timestamp an import filters its source documents by, or nil to process all of them. It is
      # the lower bound below which a record is skipped, as DownloadObject#changed_from is, but the two
      # stages resolve one mode name separately: the download nils out for FULL_MODES, the import for
      # everything outside DELTA_MODES, so full_delta downloads with no bound and imports with one.
      # @return [ActiveSupport::TimeWithZone, nil]
      def changed_from
        return unless DELTA_MODES.include?(mode.to_s)

        last_successful_try
      end

      def source_steps_successful?
        # Check if all download steps of the source_type were successful
        external_source.source_steps_successful?(source_name, :download)
      end

      def step_config(config)
        cfg = (config&.deep_dup || {}).with_indifferent_access
        options.slice(*DEFAULT_CONFIG_KEYS).with_indifferent_access.deep_merge(cfg)
      end
    end
  end
end
