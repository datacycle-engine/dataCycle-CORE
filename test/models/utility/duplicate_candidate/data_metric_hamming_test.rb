# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Utility
    module DuplicateCandidate
      # The module had no coverage when it was moved onto Base.same_locale_scope, so these cases pin
      # the behaviour that move could have changed: the trigram pre-filter on the name, and the
      # locale it reads that name in. See OnlyTitleTest for the locale rule itself.
      class DataMetricHammingTest < DataCycleCore::TestCases::ActiveSupportTestCase
        SUBJECT = DataCycleCore::Utility::DuplicateCandidate::DataMetricHamming
        TEMPLATE = 'Örtlichkeit'

        before(:all) do
          @original_schema = DataCycleCore::ThingTemplate.find_by(template_name: TEMPLATE).schema
          schema = @original_schema.deep_merge(
            'features' => { 'duplicate_candidate' => { 'allowed' => true, 'module' => ['DataMetricHamming'] } }
          )
          DataCycleCore::ThingTemplate.upsert_all([{ template_name: TEMPLATE, schema: }], unique_by: :template_name)
        end

        after(:all) do
          DataCycleCore::ThingTemplate.upsert_all([{ template_name: TEMPLATE, schema: @original_schema }], unique_by: :template_name)
        end

        def place(de:, en: nil, **properties)
          content = DataCycleCore::Thing.new(template_name: TEMPLATE)
          content.save!(touch: false)
          content.set_data_hash(data_hash: { 'name' => de }.merge(properties.stringify_keys), prevent_history: true)
          I18n.with_locale(:en) { content.set_data_hash(data_hash: { 'name' => en }, partial_update: true, prevent_history: true) } if en

          content.reload
        end

        def candidate_ids(content)
          Array.wrap(SUBJECT.duplicates(content:)).pluck(:thing_duplicate_id)
        end

        def row_for(content, duplicate)
          Array.wrap(SUBJECT.duplicates(content:)).find { |r| r[:thing_duplicate_id] == duplicate.id }
        end

        test 'an identical name and an identical schema are a candidate pair scored 100' do
          first = place(de: 'Hamming Gleich')
          second = place(de: 'Hamming Gleich')

          assert_equal({ thing_duplicate_id: second.id, method: 'data_metric_hamming', score: 100 }, row_for(first, second))
        end

        # the schema half of the rule, which the name filter cannot express: WEIGHTING (5) per
        # differing property over the 28 scored properties of Örtlichkeit, against the default
        # content_min_score of 80. One property apart still scores 82, two fall to 64.
        test 'a pair one scored property apart stays above content_min_score' do
          first = place(de: 'Hamming Schwelle')
          second = place(de: 'Hamming Schwelle', description: 'Nur hier gesetzt')

          assert_equal 82, row_for(first, second)&.fetch(:score)
        end

        test 'a pair two scored properties apart falls below content_min_score' do
          first = place(de: 'Hamming Schwelle Zwei')
          second = place(de: 'Hamming Schwelle Zwei', description: 'Nur hier gesetzt', text: 'Und hier auch')

          assert_not_includes candidate_ids(first), second.id
        end

        test 'a dissimilar name is not a candidate' do
          first = place(de: 'Hamming Eins')
          second = place(de: 'Voellig Anderer Name Ohne Bezug')

          assert_not_includes candidate_ids(first), second.id
        end

        # The case the hard-coded 'de' produced: read in English, the subject's name was scored
        # against the other content's German translation. Under :de the literal and the current
        # locale agreed, so only a run in another locale tells the two apart.
        test 'the name is scored against the same locale, not against the German translation' do
          first = place(de: 'Kirche Hirschegg', en: 'Church Hirschegg')
          second = place(de: 'Church Hirschegg', en: 'Etwas Voellig Anderes')

          I18n.with_locale(:en) { assert_not_includes candidate_ids(first.reload), second.id }
        end

        test 'a candidate matching in the current locale is still found there' do
          first = place(de: 'Kapelle Oberlech', en: 'Chapel Oberlech')
          second = place(de: 'Etwas Voellig Anderes', en: 'Chapel Oberlech')

          I18n.with_locale(:en) { assert_includes candidate_ids(first.reload), second.id }
        end

        test 'a content without a name in the current locale yields no candidates' do
          first = place(de: 'Hamming Ohne Englisch')
          place(de: 'Hamming Ohne Englisch')

          I18n.with_locale(:en) { assert_nil SUBJECT.duplicates(content: first.reload) }
        end

        test 'duplicates returns nil for a content without a name' do
          assert_nil SUBJECT.duplicates(content: struct_double(name: nil))
        end
      end
    end
  end
end
