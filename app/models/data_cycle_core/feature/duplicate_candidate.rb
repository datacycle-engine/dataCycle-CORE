# frozen_string_literal: true

module DataCycleCore
  module Feature
    class DuplicateCandidate < Base
      MODULE_BASE_PATH = 'Utility::DuplicateCandidate'

      class << self
        def content_module
          DataCycleCore::Feature::Content::DuplicateCandidate
        end

        def data_hash_module
          DataCycleCore::Feature::DataHash::DuplicateCandidate
        end

        def controller_module
          DataCycleCore::Feature::ControllerFunctions::DuplicateCandidate
        end

        def routes_module
          DataCycleCore::Feature::Routes::DuplicateCandidate
        end

        # The candidate rows for +content+, ready to be inserted into thing_duplicates.
        #
        # Runs in the default locale whoever asks. Every name-comparing rule reads the name of one
        # locale (see Utility::DuplicateCandidate::Base.same_locale_scope) while thing_duplicates
        # has no locale column, so without the pin the row set records whichever language its writer
        # happened to be in: a Feratel import processes one locale per pass inside `I18n.with_locale`
        # (Generic::Common::ImportContents.process_content) and ActiveJob hands that locale to
        # CheckForDuplicatesJob, so the English pass would write the candidates an English reader
        # sees and the next German pass would replace them. An editor saving with the backend set to
        # English would do the same, which made the stored candidates depend on who touched a
        # content last.
        #
        # The pin costs the case it excludes: a content with no name in the default locale gets no
        # candidates at all, where an English editor's save used to produce some. The nightly
        # `dc:duplicates:create_duplicates` runs at the default locale already, so the pin changes
        # no row that task writes - it stops the other writers from disagreeing with it.
        #
        # @param content [DataCycleCore::Thing] content to find candidates for
        # @return [Array<Hash>, nil] nil if no detection module is configured
        def find_duplicates(content)
          modules = modules(content)
          return if modules.blank?

          I18n.with_locale(I18n.default_locale) { collect_duplicates(content, modules) }
        end

        def allowed?(content = nil)
          super && configuration(content)['module'].present?
        end

        def modules(content)
          Array.wrap(configuration(content)['module'])
            .map { |m| DataCycleCore::ModuleService.load_module(m.classify, MODULE_BASE_PATH) }
        end

        def combined_parameters(content)
          modules(content).flat_map { |m| m.parameters(content:) }.uniq
        end

        def version_name_for_merge(duplicate, ui_locale = DataCycleCore.ui_locales.first)
          I18n.t('common.merged_with_version_name', name: I18n.with_locale(duplicate.first_available_locale) { duplicate.title }, id: duplicate.id, locale: ui_locale)
        end

        # Duplicate methods that a user set explicitly instead of a detection module. Pairs carrying
        # one of them are kept when the candidates of a content are recalculated, because no module
        # will ever re-find them (see Feature::DataHash::DuplicateCandidate#create_duplicate_candidates).
        # @return [Array<String>] reserved duplicate method identifiers
        def reserved_methods
          reserved_modules.map(&:identifier)
        end

        # The modules behind the reserved methods, which are deliberately not configured on any template
        # and therefore not part of #available_rules.
        # @return [Array<Class>]
        def reserved_modules
          [Utility::DuplicateCandidate::Manual]
        end

        # Every duplicate method a filter may select: the ones configured on templates plus the reserved
        # ones, which are written by the backend and the API but never detected by a module.
        # @return [Array<Class>]
        def selectable_rules
          (available_rules + reserved_modules).uniq
        end

        def available_rules
          DataCycleCore::ThingTemplate
            .where("thing_templates.schema -> 'features' -> 'duplicate_candidate' -> 'module' IS NOT NULL")
            .pluck(Arel.sql("thing_templates.schema -> 'features' -> 'duplicate_candidate' -> 'module'"))
            .flatten
            .uniq
            .map { |m| DataCycleCore::ModuleService.load_module(m.classify, MODULE_BASE_PATH) }
        end

        # the content of a merge group that survives: the one with the highest content score,
        # on a tie the one that was edited last (see MergePlan)
        def original_for_merge(contents)
          contents.max_by { |content| [content_score_for_merge(content), content.updated_at] }
        end

        # internal_content_score is translated and only computed for templates with the
        # ContentScore feature, so the maximum over the available locales counts and a content
        # without the feature scores 0.
        def content_score_for_merge(content)
          return 0.0 unless content.respond_to?(:internal_content_score)

          content.available_locales
            .filter_map { |locale| I18n.with_locale(locale) { content.internal_content_score }&.to_f }
            .max
            .to_f
        end

        # merges the duplicate into the original, see Merge. returns false if the pair cannot
        # be merged, raises Merge::LockedContentsError if a locked content blocked part of it.
        def merge_duplicate(original, duplicate, current_user: nil)
          Merge.call(original:, duplicate:, current_user:)
        end

        # merges triggered by a user run inline, so the duplicate is gone when the page reloads.
        # a merge writes a history entry per moved link and destroys the duplicate's embedded
        # tree, therefore only merge inline while that stays below :inline_merge_limit
        # (blank => always in the background).
        def merge_inline?(duplicate)
          limit = configuration(duplicate)[:inline_merge_limit]&.to_i
          return false if limit.blank?

          contents_affected_by_merge(duplicate).limit(limit + 1).count <= limit
        end

        private

        # Every module's rows for +content+, reduced to what thing_duplicates can hold.
        #
        # A pair keeps one row per method, the highest score winning. The insert passes
        # `unique_by: :unique_thing_duplicate_idx` and would swallow a second row for the same pair
        # and method, so a module returning two would silently decide its own score rather than
        # raise; the name rules can no longer produce one, because same_locale_scope pins them
        # to a single translation and thing_translations is unique on (thing_id, locale).
        #
        # The rows are then ordered by that same index key. It is keyed on the *unordered* pair of
        # ids and the method, so the two contents of a pair insert the very same keys, and a shared
        # order gives every writer the same lock order - which rules out insert/insert deadlocks
        # between two workers running on the two ends of a pair. Their deletes can still collide,
        # see Feature::DataHash::DuplicateCandidate#create_duplicate_candidates.
        #
        # @param content [DataCycleCore::Thing] content the rows belong to
        # @param modules [Array<Class>] the detection modules configured for its template
        # @return [Array<Hash>] candidate rows, deduplicated and ordered for a deadlock-free insert
        def collect_duplicates(content, modules)
          duplicates = []

          modules.each do |mod|
            duplicates.concat(Array.wrap(mod.duplicates(content:)))
          end

          duplicates
            .sort_by { |t| -t[:score] }
            .uniq { |t| [t[:thing_duplicate_id], t[:method]] }
            .sort_by { |t| [*[content.id, t[:thing_duplicate_id]].minmax, t[:method].to_s] }
        end

        # contents a merge has to touch: the ones linking to the duplicate (their link is moved
        # and each one writes a history entry) plus the duplicate's own embedded children (they
        # are destroyed with it). contents the duplicate merely links to stay untouched.
        def contents_affected_by_merge(duplicate)
          moved_links = DataCycleCore::ContentContent.where(content_b_id: duplicate.id)
          embedded_relations = duplicate.embedded_property_names - duplicate.virtual_property_names
          return moved_links if embedded_relations.blank?

          moved_links.or(
            DataCycleCore::ContentContent.where(content_a_id: duplicate.id, relation_a: embedded_relations)
          )
        end
      end
    end
  end
end
