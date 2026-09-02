# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      # Reverses ArchiveContents: when a previously life-cycle-archived content reappears in the source
      # (its Mongo download item is no longer marked deleted), it is set back to an active life-cycle stage
      # ("feed wins" un-archiving).
      #
      # The target stage is configurable via the +life_cycle_stage+ import option and otherwise taken from
      # the life-cycle configuration (Feature::LifeCycle.active_name). The still-present items are
      # loaded in bulk and updated across a WorkerPool (see LifeCycleContentProcessor); contents that are
      # not archived are skipped, so this can safely run over every seen item each import.
      #
      # Known cost: it resolves a Thing and enqueues a (mostly no-op) job for every still-present item, not
      # just the archived minority. Archived state is not a plain column (it is a life-cycle classification,
      # see Feature::Content::LifeCycle#archived?), so narrowing the query to archived Things is left as a
      # future optimization.
      module ReactivateContents
        extend DataCycleCore::Generic::Common::LifeCycleContentProcessor

        # Loads the download items still present in the source (default non-deleted/non-archived scopes).
        def self.load_contents(filter_object:)
          filter_object.query
        end

        # Reactivates every matching, currently-archived content in parallel; returns the number reactivated.
        def self.process_content(utility_object:, raw_data:, locale:, options:)
          raise 'Reactivate canceled (Last download(s) failed)!' unless utility_object.source_steps_successful?

          stage_name = options.dig(:import, :life_cycle_stage)
          contents = find_contents(utility_object:, raw_data:, locale:, options:)
          warm_life_cycle_classifications(contents)

          update_in_parallel(contents) do |content|
            I18n.with_locale(locale) do
              next false unless DataCycleCore::Feature::LifeCycle.allowed?(content)
              next false unless content.try(:archived?)

              content.reactivate(nil, stage_name:)
            end
          end
        end
      end
    end
  end
end
