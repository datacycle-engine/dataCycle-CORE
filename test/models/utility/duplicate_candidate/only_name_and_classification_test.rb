# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Utility
    module DuplicateCandidate
      # OnlyNameAndClassification pairs same-named contents that share a classification of the
      # configured trees - the rule imported contents without an address need (#37010), where
      # OnlyNameAndLocality returns early and NameSimilarity would pair every same-named content.
      class OnlyNameAndClassificationTest < DataCycleCore::TestCases::ActiveSupportTestCase
        include ActiveJob::TestHelper

        SUBJECT = DataCycleCore::Utility::DuplicateCandidate::OnlyNameAndClassification
        TEMPLATE = 'Artikel'

        # configures the rule on Artikel (name + a `tags` property on the Tags tree) and restores the
        # template afterwards, so no other test in the process sees the feature switched on
        before(:all) do
          @original_schema = DataCycleCore::ThingTemplate.find_by(template_name: TEMPLATE).schema
          schema = @original_schema.deep_merge(
            'features' => {
              'duplicate_candidate' => {
                'allowed' => true,
                'tree_labels' => ['Tags'],
                'module' => ['OnlyNameAndClassification']
              }
            }
          )
          DataCycleCore::ThingTemplate.upsert_all([{ template_name: TEMPLATE, schema: }], unique_by: :template_name)

          @tag_a, @tag_b = DataCycleCore::Concept.for_tree('Tags').first(2).map(&:id)
        end

        after(:all) do
          DataCycleCore::ThingTemplate.upsert_all([{ template_name: TEMPLATE, schema: @original_schema }], unique_by: :template_name)
        end

        # deliberately not TestPreparations.create_content: that returns an *existing* content of the
        # same template and name, which is exactly the case under test here. Candidates are
        # recomputed inline (CheckForDuplicatesJob does it in production) so the assertions do not
        # depend on the queue adapter.
        def article(name:, tags: [], en: nil)
          content = DataCycleCore::Thing.new(template_name: TEMPLATE)
          content.save!(touch: false)
          content.set_data_hash(data_hash: { 'name' => name, 'tags' => tags }, prevent_history: true)
          I18n.with_locale(:en) { content.set_data_hash(data_hash: { 'name' => en }, partial_update: true, prevent_history: true) } if en
          content.reload
          content.create_duplicate_candidates

          content
        end

        test 'same name and a shared classification are a candidate pair' do
          first = article(name: 'Pfarrkirche', tags: [@tag_a])
          second = article(name: 'Pfarrkirche', tags: [@tag_a])
          first.create_duplicate_candidates

          assert_equal [second.id], first.duplicate_candidates.reload.pluck(:duplicate_id)
          assert_equal [first.id], second.duplicate_candidates.reload.pluck(:duplicate_id)
          assert_equal [100], second.duplicate_candidates.reload.pluck(:score)
          assert_equal ['only_name_and_classification'], second.duplicate_candidates.reload.pluck(:duplicate_method)
        end

        test 'same name in different classifications is not a candidate' do
          first = article(name: 'Pfarrkirche Getrennt', tags: [@tag_a])
          article(name: 'Pfarrkirche Getrennt', tags: [@tag_b])
          first.create_duplicate_candidates

          assert_empty first.duplicate_candidates.reload
        end

        test 'a shared classification alone is not a candidate' do
          first = article(name: 'Kirche A', tags: [@tag_a])
          article(name: 'Kirche B', tags: [@tag_a])
          first.create_duplicate_candidates

          assert_empty first.duplicate_candidates.reload
        end

        test 'a content without any classification of the tree is not a candidate' do
          first = article(name: 'Ohne Klassifizierung')
          article(name: 'Ohne Klassifizierung')
          first.create_duplicate_candidates

          assert_empty first.duplicate_candidates.reload
        end

        # The name half of the rule is locale bound - see OnlyTitleTest for the reasoning. This is
        # the module `dc:duplicates:merge_duplicates[100,cleanup-feratel-event-locations,...]`
        # consumes, so the pair below is the score-100 candidate production offered it: two
        # different rooms sharing only the English name Feratel delivers. No merge ever consumed
        # the row, because the same nightly run recomputed the "Proberaum" end afterwards and
        # deleted it again.
        test 'names differing in the current locale are not a candidate although English agrees' do
          first = article(name: 'Walserhaus Hirschegg', tags: [@tag_a], en: 'Walserhaus Hirschegg')
          second = article(name: 'Proberaum Walserhaus Hirschegg', tags: [@tag_a], en: 'Walserhaus Hirschegg')
          first.create_duplicate_candidates

          assert_empty first.duplicate_candidates.reload
          assert_empty second.duplicate_candidates.reload
        end

        test 'names agreeing in the current locale stay a candidate although English differs' do
          first = article(name: 'Parkplatz Adolari', tags: [@tag_a], en: 'Parkplatz Adolari')
          second = article(name: 'Parkplatz Adolari', tags: [@tag_a], en: 'parking space Adolari')
          first.create_duplicate_candidates

          assert_equal [second.id], first.duplicate_candidates.reload.pluck(:duplicate_id)
        end

        # Feature::DuplicateCandidate.find_duplicates pins the recomputation, so the row set no longer
        # depends on the language its writer happened to be in. Without the pin the English Feratel
        # import pass would store exactly the pair the change removes.
        test 'recomputation is pinned to the default locale whatever locale the writer is in' do
          first = article(name: 'Walserhaus Hirschegg', tags: [@tag_a], en: 'Walserhaus Hirschegg')
          second = article(name: 'Proberaum Walserhaus Hirschegg', tags: [@tag_a], en: 'Walserhaus Hirschegg')

          I18n.with_locale(:en) do
            first.create_duplicate_candidates
            second.create_duplicate_candidates
          end

          assert_empty first.duplicate_candidates.reload
          assert_empty second.duplicate_candidates.reload
        end

        # every other locale case in this file runs through create_duplicate_candidates, which pins
        # the locale and would therefore hide a module scope that still crossed the two
        test 'the module compares the name in the current locale' do
          first = article(name: 'Alpha Haus', tags: [@tag_a], en: 'Beta Haus')
          crossing = article(name: 'Beta Haus', tags: [@tag_a], en: 'Gamma Haus')
          agreeing = article(name: 'Delta Haus', tags: [@tag_a], en: 'Beta Haus')

          I18n.with_locale(:en) do
            ids = Array.wrap(SUBJECT.duplicates(content: first.reload)).pluck(:thing_duplicate_id)

            assert_not_includes ids, crossing.id
            assert_includes ids, agreeing.id
          end
        end

        test 'a content without a name in the current locale yields no candidates' do
          first = article(name: 'Ohne Englische Uebersetzung', tags: [@tag_a])
          article(name: 'Ohne Englische Uebersetzung', tags: [@tag_a])

          I18n.with_locale(:en) { assert_nil SUBJECT.duplicates(content: first.reload) }
        end

        test 'duplicates returns nil for a content without a name' do
          assert_nil SUBJECT.duplicates(content: struct_double(name: nil))
        end

        # the classification is half the rule, so a change to it has to enqueue the recalculation
        test 'parameters cover the name and the classification properties of the template' do
          content = article(name: 'Parameter Probe', tags: [@tag_a])

          assert_includes SUBJECT.parameters(content:), 'name'
          assert_includes SUBJECT.parameters(content:), 'tags'
          assert_includes DataCycleCore::Feature::DuplicateCandidate.combined_parameters(content), 'tags'
        end
      end
    end
  end
end
