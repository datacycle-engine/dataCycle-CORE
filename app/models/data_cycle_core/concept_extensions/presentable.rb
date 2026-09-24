# frozen_string_literal: true

module DataCycleCore
  module ConceptExtensions
    # What a serializer reads off a concept: its translations, the locale it renders in, its badge and
    # the ancestry an API response lists. DataCycleCore::Concept::History answers the same questions
    # for a deleted concept - the API's since-deleted filters serialize history rows through the very
    # same partials - so both include this instead of each carrying a copy.
    module Presentable
      extend ActiveSupport::Concern

      included do
        extend ::Mobility

        translates :name, :description, column_suffix: '_i18n', backend: :jsonb

        scope :with_locale, lambda { |locales|
          Array.wrap(locales)
            .map { |l| where("#{quoted_table_name}.name_i18n ->> '#{l}' IS NOT NULL AND #{quoted_table_name}.name_i18n ->> '#{l}' != ''") }
            .inject { |scope, query| scope.or(query) }
        }

        # a deleted concept whose scheme is deleted too has none, and reads as invisible
        delegate :visible?, to: :concept_scheme, allow_nil: true
      end

      def translated_locales
        @translated_locales ||= (
          name_i18n.compact_blank.keys.map(&:to_sym) +
          description_i18n.compact_blank.keys.map(&:to_sym)
        ).uniq
      end
      alias available_locales translated_locales

      def first_available_locale(locale = nil)
        (Array.wrap(locale).map(&:to_sym).sort_by { |t| locale_priority(t) }.push(I18n.locale) & translated_locales).first || translated_locales.min_by { |t| locale_priority(t) }
      end

      # The ancestry an API response lists, nearest first and ending in the scheme. #ancestors itself
      # stops at the topmost concept, because concept_paths.ancestor_ids holds concepts only, but API
      # v1-v3 and the xml interface have always emitted the scheme as the last entry.
      def ancestors_with_concept_scheme
        [*ancestors, concept_scheme].compact
      end

      def color
        ui_configs['color']
      end

      def color?
        color.present?
      end

      def icon
        icon = DataCycleCore.classification_icons[id] ||
               DataCycleCore.classification_icons[concept_scheme&.id] ||
               DataCycleCore.classification_icons[external_key] ||
               DataCycleCore.classification_icons[full_path]

        return if icon.blank?

        DataCycleCore::LocalizationService.view_helpers.dc_image_url("icons/#{icon}")
      end

      def icon?
        icon.present?
      end
    end
  end
end
