# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      # Life-cycle-archives contents whose Mongo download item has been marked deleted, instead of
      # hard-deleting them (as DeleteContentsSafe does).
      #
      # It uses the replace-based Feature::DataHash::LifeCycle#archive (which sets the single-valued
      # life-cycle attribute — e.g. +data_pool+ — to the configured archive stage). Additive strategies
      # such as UpdateAttributes / DeleteContentsUpdateAttributes cannot archive here: the life-cycle
      # attribute holds only one value, so unioning in "Archiv" is dropped and +archived?+ never flips.
      #
      # The deleted items are loaded in bulk and archived across a WorkerPool (see LifeCycleContentProcessor).
      # Pair it with DownloadBulkMarkDeleted using a grace period (e.g. +seen_at <= 3.days.ago+) so items
      # are archived only after being absent from the source for that period, and with ReactivateContents
      # to bring them back when they reappear.
      module ArchiveContents
        extend DataCycleCore::Generic::Common::LifeCycleContentProcessor

        # Loads the download items marked deleted (dropping the default non-deleted/non-archived scopes).
        def self.load_contents(filter_object:)
          filter_object.except(:without_deleted, :without_archived).with_deleted.query
        end

        # Archives every matching, not-yet-archived content in parallel; returns the number archived.
        def self.process_content(utility_object:, raw_data:, locale:, options:)
          raise 'Archive canceled (Last download(s) failed)!' unless utility_object.source_steps_successful?

          contents = find_contents(utility_object:, raw_data:, locale:, options:)
          warm_life_cycle_classifications(contents)

          update_in_parallel(contents) do |content|
            I18n.with_locale(locale) do
              next false unless DataCycleCore::Feature::LifeCycle.allowed?(content)
              next false if content.try(:archived?)
              next false unless content.archive

              DataCycleCore::Generic::Common::ImportCounters.instrument(:archived, utility_object:, template_name: content.template_name)

              true
            end
          end
        end
      end
    end
  end
end
