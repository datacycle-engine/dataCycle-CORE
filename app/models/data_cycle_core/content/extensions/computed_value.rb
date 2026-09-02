# frozen_string_literal: true

module DataCycleCore
  module Content
    module Extensions
      module ComputedValue
        extend ActiveSupport::Concern

        # Options of the triggering save that the compute.after_save recompute has to run with.
        # The recompute is a continuation of that save on the same record, so anything it does not
        # inherit silently falls back to a DataHashOptions default and overwrites the caller's
        # intent — prevent_history would be re-armed, version_name blanked, updated_by cleared.
        # Deliberately excluded: new_content, source, force_update and template_changed describe
        # the caller's write, not the recompute's.
        AFTER_SAVE_INHERITED_OPTIONS = [
          :current_user, :prevent_history, :invalidate_related_cache,
          :update_search_all, :version_name, :save_time, :ui_locale
        ].freeze

        def update_computed_values(keys:)
          return if keys.blank?

          computed_keys = keys.intersection(computed_property_names)
          translated_computed = computed_keys.intersection(translatable_property_names)

          if translated_computed.present?
            available_locales.each do |locale|
              keys = locale == first_available_locale ? computed_keys : translated_computed
              update_computed_values_for_locale(keys:, locale:)
            end
          else
            update_computed_values_for_locale(keys: computed_keys)
          end
        end

        # @param set_data_hash_options [Hash] options forwarded to the storing #set_data_hash.
        #   Background recomputes (the async job, a classification change) pass none and get the
        #   defaults; the in-request compute.after_save pass forwards
        #   AFTER_SAVE_INHERITED_OPTIONS so it does not overwrite the triggering save's intent.
        # @return [Boolean] whether the recomputed value could be stored
        def update_computed_values_for_locale(keys:, locale: nil, **set_data_hash_options)
          I18n.with_locale(first_available_locale(locale)) do
            data_hash = {}
            calculate_computed_values(data_hash:, keys:, current_user: set_data_hash_options[:current_user], force: true)
            set_data_hash(data_hash:, **set_data_hash_options)
          end
        end

        # True while the compute.after_save recompute is running its own #set_data_hash. The
        # recompute writes the same record as the save that triggered it, so DataHash reads this to
        # keep that nested pass from repeating the caller-facing side effects of one save (update
        # webhooks, subscriber mails).
        #
        # Scope: this gates those three statements inside DataHash#after_save_data_hash, not the
        # whole after_save hook. The job enqueues in that same method body still run for the
        # recompute pass (dependent computed properties, related cache invalidation, exif values),
        # and so does every after_save_data_hash a feature prepends — including the two that branch
        # on previous_datahash_changes (Feature::DataHash::AutoGeocode, ::Aggregate), which during
        # the recompute pass holds the recomputed key instead of the caller's diff. Neither can fire
        # for the primary-icon computes, whose only written key is neither a watched address key nor
        # an aggregate_for. Widening the gate to cover prepended hooks is deliberately not
        # attempted: AutoGeocode's stale-tag cleanup emits a webhook from its own nested
        # set_data_hash on purpose, so a blanket suppression would swallow an intended effect.
        #
        # @return [Boolean]
        def updating_after_save_computed_values?
          @updating_after_save_computed_values.present?
        end

        private

        # Recalculates the compute.after_save properties that the preceding before_save pass
        # deferred (see #update_computed_values_after_save). Called from #set_data_hash inside the
        # write transaction, after the record was saved and reloaded, so a compute reading the
        # stored state — e.g. the collected_classification_contents its triggers only fill after
        # the classification_contents rows are written — sees the final state, as the async job
        # would.
        #
        # Unlike the async job this runs in the caller's request, so the value is committed before
        # the response is sent and the detail view rendered after the save-redirect already shows
        # it.
        #
        # The recompute performs its own #set_data_hash, whose before_save pass may defer keys
        # again; @updating_after_save_computed_values stops that from recursing. Such a second-level
        # deferral is **dropped**: a compute.after_save property that depends on another one is not
        # supported and stays stale until an unrelated save or the classification-change recompute
        # touches it — declare the dependent property `async: true` instead.
        #
        # Runs with the triggering save's options (AFTER_SAVE_INHERITED_OPTIONS) because it writes
        # the caller's own record, and restores the caller's warnings afterwards: falling out on
        # no_changes — the normal outcome when the recomputed value is unchanged — otherwise leaves
        # a "nothing was saved" warning on the object the controller renders. Errors are
        # deliberately **not** restored; they are how a failed recompute reaches the caller.
        #
        # A raising compute is deliberately not caught, matching the inline pass: the error
        # propagates out of the enclosing write transaction, so the save is rolled back rather
        # than stored with a missing or wrong computed value. A value the schema rejects is
        # reported through the return value for the same reason.
        #
        # Reporting a rejected value through the return value instead of through @errors rests on an
        # invariant of the enclosing DataHash#set_data_hash: it has exactly two false returns — the
        # validate of the caller's own data and the recompute below — and the first always populates
        # errors, because #validate's add_errors defaults to true. That is what makes a rolled-back
        # save impossible to observe as i18n_valid?, which the controller would report as success
        # over a discarded edit. A future false return added to #set_data_hash without adding an
        # error would break that quietly.
        #
        # @param options [DataCycleCore::Content::DataHashOptions] options of the triggering save
        # @return [Boolean] false when the recomputed value could not be stored
        def update_after_save_computed_values(options)
          return true if @after_save_computed_keys.blank? || updating_after_save_computed_values?

          saved_warnings = @warnings.deep_dup

          begin
            @updating_after_save_computed_values = true
            update_computed_values_for_locale(
              **@after_save_computed_keys,
              **options.to_h.slice(*AFTER_SAVE_INHERITED_OPTIONS)
            )
          ensure
            @warnings = saved_warnings
            @after_save_computed_keys = nil
            @updating_after_save_computed_values = false
          end
        end

        # Discards a compute.after_save deferral that was never consumed. Consuming one clears it
        # itself, so this only covers a pass that bailed out between deferring and consuming
        # (invalid data, no changes) — without it that stale deferral would be recomputed on behalf
        # of an unrelated save. Called by DataHash#set_data_hash, which both creates and consumes
        # the deferral and is the only method able to observe that window.
        #
        # Unconditional on purpose: the deferral is fed from after_save_computed_property_names and
        # is therefore always nil for a content without such a property, so gating this would cost
        # a property_definitions scan to skip a single assignment.
        #
        # @return [void]
        def reset_after_save_computed_keys
          @after_save_computed_keys = nil
        end

        def add_computed_values(data_hash:, keys:, current_user: nil)
          return if keys.blank?

          inline_keys = inline_computed_property_names.intersection(keys)
          async_keys = async_computed_property_names.intersection(keys)
          after_save_keys = after_save_computed_property_names.intersection(keys)

          calculate_computed_values(data_hash:, current_user:, keys: inline_keys) if inline_keys.present?
          update_computed_values_async(async_keys, I18n.locale) if async_keys.present?
          defer_after_save_computed_values(after_save_keys, I18n.locale) if after_save_keys.present?
        end

        # Records what #update_after_save_computed_values has to recalculate once the save is
        # written. Deferring here rather than re-deriving it post-save keeps the decision with the
        # diff that produced it, including the "locale does not exist yet" case in
        # DataHash#check_update_computed. Fed only from after_save_computed_property_names, which
        # is what lets DataHash#set_data_hash gate the entire mode on this being present.
        #
        # @param keys [Array<String>] compute.after_save keys to recalculate
        # @param locale [String, Symbol] locale the triggering save runs in
        # @return [void]
        def defer_after_save_computed_values(keys, locale)
          @after_save_computed_keys = { keys:, locale: }
        end

        def calculate_computed_values(keys:, data_hash: {}, current_user: nil, force: false)
          return if keys.blank?

          Array.wrap(keys).each do |computed_property|
            DataCycleCore::Utility::Compute::Base.compute_values(computed_property, data_hash, self, current_user, force)
          end
        end

        def update_computed_values_async(keys, language)
          return if keys.blank?

          DataCycleCore::UpdateAsyncComputedPropertiesJob.perform_later(id, keys, language)
        end
      end
    end
  end
end
