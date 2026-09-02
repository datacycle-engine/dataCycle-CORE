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
        # @return [Array<Hash>, nil] nil if no detection module is configured
        def find_duplicates(content)
          modules = modules(content)
          return if modules.blank?

          duplicates = []

          modules.each do |mod|
            duplicates.concat(Array.wrap(mod.duplicates(content:)))
          end

          # one row per duplicate and method (a module matches per translation and reports a pair
          # once per matching one, see OnlyTitle and NameSimilarity), the best score of each wins
          duplicates = duplicates.sort_by { |t| -t[:score] }.uniq { |t| [t[:thing_duplicate_id], t[:method]] }

          # unique_thing_duplicate_idx is keyed on the *unordered* pair of ids and the method, so the
          # two contents of a pair insert the very same keys. Ordering them by that key gives every
          # writer the same lock order, which rules out insert/insert deadlocks between two workers
          # running on the two ends of a pair - their deletes can still collide, see
          # Feature::DataHash::DuplicateCandidate#create_duplicate_candidates.
          duplicates.sort_by { |t| [*[content.id, t[:thing_duplicate_id]].minmax, t[:method].to_s] }
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
