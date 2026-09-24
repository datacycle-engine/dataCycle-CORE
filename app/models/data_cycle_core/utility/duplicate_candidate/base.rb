# frozen_string_literal: true

module DataCycleCore
  module Utility
    module DuplicateCandidate
      class Base
        include ActiveModel::Model

        FEATURE = DataCycleCore::Feature::DuplicateCandidate
        PARAMETERS = [].freeze

        class << self
          # def duplicates(content:, **)
          #   raise NotImplementedError, "You must implement #{self.class}##{__method__}"
          # end

          def parameters(**)
            self::PARAMETERS
          end

          def identifier
            name.demodulize.underscore
          end

          def feature
            self::FEATURE
          end

          def by_identifier(identifier)
            DataCycleCore::ModuleService.load_module(identifier.classify, 'Utility::DuplicateCandidate')
          end

          def to_select_option(locale = DataCycleCore.ui_locales.first)
            DataCycleCore::Filter::SelectOption.new(
              id: identifier,
              name: model_name.human(count: 1, locale:),
              html_class: identifier,
              dc_tooltip: model_name.human(count: 1, locale:),
              class_key: identifier
            )
          end

          private

          # The other contents of the same template, restricted to the one translation a name
          # comparison may look at. Every rule that compares names builds on this - OnlyTitle,
          # OnlyNameAndLocality, OnlyNameAndClassification, NameSimilarity and DataMetricHamming -
          # so the locale rule is stated once, here.
          #
          # `content.name` resolves in the current locale and nothing else: Mobility runs without
          # its fallbacks plugin (config/initializers/mobility.rb) and lib/data_cycle_core.rb sets
          # `config.i18n.fallbacks = false`. Mobility does not restrict the other side of the
          # comparison for us. Its query plugin - `Thing.default_scope { i18n }` - rewrites a
          # predicate only where the predicate names a translated attribute, `slug` or `content`:
          # `Thing.where(slug: 'x')` joins `thing_translations_de ... AND locale = 'de'`, while
          # these rules compare `thing_translations.content ->> 'name'`, raw SQL the plugin never
          # sees. `Thing.joins(:translations).where(template_name: ...)` therefore emits no locale
          # predicate at all, and that join carried every locale of every other content, scoring
          # two contents alike that agree in no single language.
          #
          # Content::Searchable#with_translation already spells out the predicate the join needs,
          # so this only adds the template and drops the content itself.
          #
          # Which locale it is does not depend on the caller:
          # Feature::DuplicateCandidate.find_duplicates pins every stored recomputation to the
          # default locale.
          #
          # The pair this closes, and the measurements behind comparing one locale rather than
          # demanding agreement in all of them, are in
          # test/models/utility/duplicate_candidate/only_title_test.rb.
          #
          # @param content [DataCycleCore::Thing] the content candidates are computed for
          # @return [ActiveRecord::Relation] things of the same template, joined to their
          #   translation in the current locale, excluding +content+ itself
          def same_locale_scope(content)
            DataCycleCore::Thing
              .with_translation
              .where(template_name: content.template_name)
              .where.not(id: content.id)
          end

          # The rows find_duplicates expects from a rule that scores every match it finds alike:
          # one per matched content, tagged with this rule's identifier. Rules whose score varies
          # per match build their rows themselves - NameSimilarity scales a trigram similarity,
          # DataMetricHamming an attribute diff - so they do not come through here.
          # @param thing_ids [Array<String>] ids of the matched contents
          # @param score [Integer] the rule's confidence in a match, 0-100
          # @return [Array<Hash>]
          def candidate_rows(thing_ids, score:)
            thing_ids.uniq.map { |id| { thing_duplicate_id: id, method: identifier, score: } }
          end
        end
      end
    end
  end
end
