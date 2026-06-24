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

        def find_duplicates(content)
          modules = modules(content)
          return if modules.blank?

          duplicates = []

          modules.each do |mod|
            duplicates.concat(Array.wrap(mod.duplicates(content:)))
          end

          duplicates.sort_by! { |t| -t[:score] }

          duplicates
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

        def available_rules
          DataCycleCore::ThingTemplate
            .where("thing_templates.schema -> 'features' -> 'duplicate_candidate' -> 'module' IS NOT NULL")
            .pluck(Arel.sql("thing_templates.schema -> 'features' -> 'duplicate_candidate' -> 'module'"))
            .flatten
            .uniq
            .map { |m| DataCycleCore::ModuleService.load_module(m.classify, MODULE_BASE_PATH) }
        end
      end
    end
  end
end
