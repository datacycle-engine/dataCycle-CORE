# frozen_string_literal: true

module DataCycleCore
  module Feature
    module DataHash
      # Both ends of DataCycleCore::Feature::LocaleInheritance: the inheriting content pulls the
      # locales of the contents it links to, and a content that just gained a locale hands it on to
      # the contents inheriting from it.
      module LocaleInheritance
        # Notes whether this save creates the locale it writes, which is what the inherited side has
        # to react to. Captured before +super+: add_default_values reads attributes of the locale
        # being written and Mobility builds its translation on read, after which available_locales
        # already reports the locale as present.
        #
        # @param options [DataCycleCore::Content::DataHashOptions]
        # @return [void]
        def before_save_data_hash(options)
          # embedded contents never inherit (see #after_save_data_hash), so they must not pay the
          # thing_translations query available_locales runs for a flag nothing reads
          return super if embedded?

          @locale_inheritance_new_locale = available_locales.exclude?(I18n.locale)

          super
        end

        # @param options [DataCycleCore::Content::DataHashOptions]
        # @return [void]
        def after_save_data_hash(options)
          # read before +super+: a feature module listed earlier in features.yml is prepended
          # earlier and therefore runs inside it, and the nested saves of one (DataHash::Aggregate)
          # replace the changes of this save with their own
          caller_changes = previous_datahash_changes

          super

          return if embedded?

          inherit_missing_locales(options, caller_changes) if inherit_locales?(options, caller_changes)

          # the inheriting side is only reached through its own save, so a content that just gained
          # a locale has to hand it on to the things referencing it. Checked here rather than in the
          # job, which would otherwise be enqueued for every content an import translates.
          return unless @locale_inheritance_new_locale
          return unless DataCycleCore::Feature::LocaleInheritance.inheriting_things(self).exists?

          DataCycleCore::LocaleInheritanceJob.perform_later(id)
        end

        # Creates a translation for every locale one of the inherited linked contents has and this
        # content does not. Writing the linked ids in the missing locale is what materializes it:
        # DataHash#check_update_computed recomputes every computed property with untranslatable
        # dependencies for a locale that does not exist yet, so the new translation comes out filled
        # with the inherited values — and is created even when those are all blank, a locale that
        # does not exist yet differing in its slug and dummy defaults alone.
        #
        # @param options [DataCycleCore::Content::DataHashOptions, nil] options of the triggering
        #   save, which the writes below continue on the same record and therefore have to run with.
        #   The job and the backfill task have no triggering save and pass none.
        # @param caller_changes [Hash, nil] changes of the triggering save, read before the other
        #   feature modules ran (see #after_save_data_hash)
        # @return [void]
        def inherit_missing_locales(options = nil, caller_changes = previous_datahash_changes)
          # an embedded content is written through its parent, and a template that is not
          # translatable has no locales to create, whatever its links have. Guarded here rather than
          # per caller so save, job and backfill task cannot disagree.
          return if @inheriting_locales || embedded? || !translatable?

          keys = DataCycleCore::Feature::LocaleInheritance.attribute_keys(self).intersection(linked_property_names)
          # read once, outside the locale blocks below: the ids do not depend on the locale, but
          # loading them in one the linked content does not have yet would come up empty
          linked_ids = keys.index_with { |k| Array.wrap(try(k)).map(&:id) }.compact_blank
          return if linked_ids.blank?

          missing_locales = inheritable_locales(linked_ids.values.flatten) - translated_locales
          return if missing_locales.blank?

          # the nested saves below run on self, so everything they leave behind on the instance
          # would be read as state of the save that got us here
          saved_warnings = @warnings.deep_dup
          saved_errors = @errors.deep_dup
          saved_new_locale = @locale_inheritance_new_locale

          begin
            @inheriting_locales = true
            @inheriting_within_caller_save = !options.nil?
            # the write continues the triggering save on the same things row, so anything it does not
            # inherit falls back to a DataHashOptions default and overwrites that save's intent —
            # blanking its version_name and updated_by, and adding an authorless history entry per
            # locale. Same reasoning, same list as the compute.after_save recompute.
            inherited_options = options.to_h.slice(*DataCycleCore::Content::Extensions::ComputedValue::AFTER_SAVE_INHERITED_OPTIONS)

            missing_locales.each do |locale|
              # a savepoint around everything the write touches, not just around set_data_hash's own
              # transaction: what runs before that one — the computed values of before_save_data_hash
              # above all — can hit the statement_timeout too, and a locale that cannot be written
              # must take neither the remaining ones nor the triggering save with it. Without a
              # savepoint of this reach, that save's transaction stays aborted and the rescue below
              # logs into a connection nothing can be read from any more.
              transaction(joinable: false, requires_new: true) do
                I18n.with_locale(locale) do
                  set_data_hash(data_hash: linked_ids, **inherited_options)

                  # not the return value: DataHash#no_changes reports true without having written a
                  # translation, and does so whenever the linked ids alone produce no diff — they are
                  # not stored per locale, so a template without a computed, default or slug value
                  # has nothing that differs in the new locale
                  next if translated_locales.include?(locale)

                  Rails.logger.error("could not inherit locale :#{locale} for thing #{id}: #{errors.full_messages.presence&.join(', ') || 'nothing to write in that locale'}")
                end
              end
            rescue StandardError => e
              # the concurrency key of LocaleInheritanceJob is the source, so two runs can hand this
              # content the same locale at once: the loser fails on the unique index over a
              # translation that now exists, which is an outcome rather than a miss
              next if DataCycleCore::Thing::Translation.exists?(thing_id: id, locale:)

              Rails.logger.error("could not inherit locale :#{locale} for thing #{id}: #{e.class} — #{e.message}")
            end
          ensure
            @inheriting_locales = false
            @inheriting_within_caller_save = false
            # the save that got us here is already committed, so a locale that could not be written
            # must not report as that save's own outcome — i18n_warnings and i18n_valid? span every
            # locale, not just the one being saved, so its warnings and errors would be read as the
            # caller's. The inheritance is retried by the next save of either side.
            @warnings = saved_warnings
            @errors = saved_errors
            # both are read once the nested save returns: the changes by
            # set_data_hash_with_translations, the flag by the enqueue in after_save_data_hash
            self.previous_datahash_changes = caller_changes
            @locale_inheritance_new_locale = saved_new_locale
          end
        end

        # The triggering save reports the record to webhooks and subscribers from its own after_save
        # pass, and both are delivered from a job that re-reads it — so the writes of
        # #inherit_missing_locales are already covered by that one report. The job and the backfill
        # task have no such pass: there the write is the only report there is.
        #
        # @return [Boolean]
        def continuing_caller_save?
          @inheriting_within_caller_save || super
        end

        private

        # Locales of the linked contents, read in one query rather than through
        # Thing.translated_locales, which would send a pluck for ids that are already at hand. And
        # restricted to the ones the application is configured for: translated_locales is
        # intersected with those too, so any other would count as missing forever and be rewritten
        # on every trigger.
        def inheritable_locales(ids)
          locales = DataCycleCore::Thing::Translation.where(thing_id: ids).distinct.pluck(:locale)

          I18n.available_locales.intersection(locales.map(&:to_sym))
        end

        # Only the writes that can change what there is to inherit: creating the content, and
        # changing one of the inherited links. Every other save would re-run the same comparison
        # to no effect — including the nested saves of #inherit_missing_locales itself.
        def inherit_locales?(options, caller_changes)
          # asked before allowed?, which builds its memoize key from an unmemoized recursive schema
          # traversal: every save of every translatable content would otherwise pay for it, whether
          # or not its template inherits anything
          return false unless DataCycleCore::Feature::LocaleInheritance.inheriting_properties.key?(template_name)
          return false unless DataCycleCore::Feature::LocaleInheritance.allowed?(self)

          options.new_content ||
            DataCycleCore::Feature::LocaleInheritance.attribute_keys(self).intersect?(Array.wrap(caller_changes&.keys))
        end
      end
    end
  end
end
