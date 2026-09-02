# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      module Extensions
        # Which keys inside dump.<locale> belong to DataCycle rather than to the source, and which
        # step is allowed to (over)write an item already stored in a collection.
        #
        # Mixed into DownloadContentFunctions, so every download strategy routed through
        # DownloadFunctions gets it. The long form -- what [#50666] was, why the whole key set is
        # stripped rather than one more key namespaced, and what lifting the priority cap would cost
        # -- is in guides/overview.md, "Internal dump keys and step priority".
        module DumpKeyPolicy
          # Step config keys copied into the dump as they are (`priority` is renamed, see
          # #props_from_config).
          CONFIG_PROPS = [:tree_label, :external_id_prefix, :concept_scheme_name, :priority].freeze

          # Key a step's configured `priority` is stored under. Namespaced because `priority` is a
          # DataCycle download concept while source payloads legitimately carry a field of that name
          # (Intermaps SRM ships a display-order `priority`).
          STEP_PRIORITY_KEY = 'dc_step_priority'

          # Priority a step runs at when it configures none. Lower number = higher priority. Such a
          # step stores *no* claim, which stays equivalent to storing this value only while no step
          # runs above it -- ExternalSystemStepContract rejects such a config and #clamp_step_priority
          # holds the line for one imported before that rule, because stamping the default into every
          # dump instead would rewrite all of them once.
          DEFAULT_STEP_PRIORITY = 5

          # Keys inside dump.<locale> that DataCycle writes itself and reads back to steer the
          # pipeline. Incoming source data is stripped of the whole set (#strip_internal_keys!), so
          # whatever is stored under one of them is always ours.
          #
          # Deliberately absent:
          # - `external_system`: internal all the same, but not merely dropped -- its credential_keys
          #   are harvested onto the mongo item first, so DownloadContentFunctions
          #   #harvest_external_system! handles it at the same three call sites.
          # - `id`, `name`, `uri`, `parent_id`: source-owned, DataCycle only fills them in when blank.
          # - `updated_at`: DataCycle writes it from the `modified` callback, but a source-owned value
          #   is read as a delta filter by Import::FilterObject#with_updated_since_filter.
          # - `tree_label`, `concept_scheme_name`, `external_id_prefix` (the rest of CONFIG_PROPS):
          #   stamped from the step config and read back by ImportConcepts, but
          #   DownloadConceptTranslations copies a whole dump from one collection into the next and
          #   relies on carrying them through, so by name alone they cannot be told apart from source
          #   data. Namespacing them is the remaining gap and needs a data migration.
          INTERNAL_DUMP_KEYS = [
            STEP_PRIORITY_KEY,
            'dc_external_id',
            'deleted_at', 'delete_reason', 'last_seen_before_delete',
            'archived_at', 'archive_reason', 'last_seen_before_archived',
            'mark_for_update'
          ].freeze

          # Pre-fills the priority the concept strategies claim what they write at. Only they need it:
          # their collections already store the default, so dropping it there is what would rewrite
          # them, while every other strategy stores no claim when it configures none. Called on the
          # module rather than through the mixin, because those strategies hand their options to
          # DownloadFunctions instead of extending this themselves.
          def self.with_default_step_priority(options)
            return options unless options.dig(:download, :priority).nil?

            options.deep_merge(download: { priority: DEFAULT_STEP_PRIORITY })
          end

          protected

          # Removes DataCycle's own keys from incoming source data, so nothing a source ships can be
          # read back as one of ours. Call it before any of them is written, not after.
          #
          # Mutates in place and keeps the receiver's class on purpose: the from-data strategies hand
          # over a BSON::Document whose indifferent lookups the callers rely on, and `except` would
          # return a plain Hash. Both key forms are deleted because plain symbol-keyed hashes reach
          # here too (a BSON::Document normalises the symbol, so the second delete is a no-op there).
          def strip_internal_keys!(item_data)
            return item_data unless item_data.is_a?(::Hash)

            INTERNAL_DUMP_KEYS.each do |key|
              item_data.delete(key)
              item_data.delete(key.to_sym)
            end

            item_data
          end

          # The only writer of the stored claim: no priority arriving with a payload is trusted, not
          # even one DataCycle stamped upstream -- that one belongs to the step which wrote *that*
          # collection, not to this one.
          def props_from_config(options:)
            props = options[:download]&.slice(*CONFIG_PROPS)&.stringify_keys || {}
            # nil rather than key? -- an empty `priority:` passes the latter, and a config stored before
            # the contract rejected one would stamp an explicit null into every dump the step writes
            priority = clamp_step_priority(props.delete('priority'))
            props[STEP_PRIORITY_KEY] = priority unless priority.nil?
            props
          end

          # Whether the current step may (over)write the item already stored in the target collection.
          # Only the namespaced STEP_PRIORITY_KEY counts: a bare `priority` in the dump may well be
          # the source's own field and must never be mistaken for a step priority.
          # An unconfigured step runs at DEFAULT_STEP_PRIORITY, so it still loses against an
          # explicitly prioritised item (5 <= 0/1/2 is false) but can refresh a defaulted one.
          def item_allowed?(local_item:, options:)
            item_priority = stored_step_priority(local_item)

            return true if item_priority.nil? # nothing has claimed it yet -> any step may write

            step_priority(options) <= item_priority
          end

          # The dump comes back from mongo as a BSON::Document (indifferent, string-keyed); the symbol
          # lookup keeps plain symbol-keyed hashes working for callers and tests.
          #
          # Only a Numeric is a claim. Anything else cannot have come from a step config that passes
          # ExternalSystemStepContract, and comparing it would raise and take the whole step down
          # instead of being ignored. Deliberately not Integer(): that coerced "2" but not "2.9",
          # and truncated 2.9 to 2, so a stored value was honoured or dropped by a rule nobody could
          # predict from reading it.
          def stored_step_priority(local_item)
            return if local_item.blank?

            priority = local_item[STEP_PRIORITY_KEY]
            priority = local_item[STEP_PRIORITY_KEY.to_sym] if priority.nil?

            priority if priority.is_a?(Numeric)
          end

          # A `priority:` that is not a number falls back to the default rather than to 0, which to_i
          # would return and which is the *highest* priority there is.
          def step_priority(options)
            priority = clamp_step_priority(options.dig(:download, :priority))

            priority.is_a?(Numeric) ? priority : DEFAULT_STEP_PRIORITY
          end

          # The range ExternalSystemStepContract rejects a config outside of, enforced again at
          # runtime: the contract only runs at config import, and nothing re-validates a
          # download_config already stored. Both readers of a configured priority go through here, the
          # gate and the claim #props_from_config stores -- a step whose gate clamped to 0 while it
          # still claimed -1 would lock itself out of its own items.
          #
          # A non-number is passed through untouched: #step_priority falls back to the default and
          # #stored_step_priority reads such a claim as none, while turning it into an explicit claim
          # here would rewrite those dumps once for a config that is invalid either way.
          def clamp_step_priority(priority)
            priority.is_a?(Numeric) ? priority.clamp(0, DEFAULT_STEP_PRIORITY) : priority
          end
        end
      end
    end
  end
end
