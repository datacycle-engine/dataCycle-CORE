# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Utility
    module DuplicateCandidate
      # Unlike the exact-match rules this one scores by trigram similarity, so both the `%` operator
      # and the reported score have to look at the same locale on both sides - otherwise a candidate
      # carries a score an editor cannot see the basis for. See OnlyTitleTest for the locale rule.
      class NameSimilarityTest < DataCycleCore::TestCases::ActiveSupportTestCase
        SUBJECT = DataCycleCore::Utility::DuplicateCandidate::NameSimilarity
        TEMPLATE = 'Artikel'

        def article(de:, en: nil)
          content = DataCycleCore::Thing.new(template_name: TEMPLATE)
          content.save!(touch: false)
          content.set_data_hash(data_hash: { 'name' => de }, prevent_history: true)
          I18n.with_locale(:en) { content.set_data_hash(data_hash: { 'name' => en }, partial_update: true, prevent_history: true) } if en

          content.reload
        end

        def rows_for(content, duplicate)
          Array.wrap(SUBJECT.duplicates(content:)).select { |r| r[:thing_duplicate_id] == duplicate.id }
        end

        test 'an identical name scores 100' do
          first = article(de: 'Auenhuette Hirschegg')
          second = article(de: 'Auenhuette Hirschegg')

          assert_equal [100], rows_for(first, second).pluck(:score)
        end

        test 'a similar name is a candidate' do
          first = article(de: 'Auenhuette Hirschegg')
          second = article(de: 'Auenhuette, Hirschegg')

          assert_not_empty rows_for(first, second)
        end

        test 'a dissimilar name is not a candidate' do
          first = article(de: 'Auenhuette Hirschegg')
          second = article(de: 'Voellig Anderer Name Ohne Bezug')

          assert_empty rows_for(first, second)
        end

        test 'similarity in another locale alone is not a candidate' do
          first = article(de: 'Walserhaus Hirschegg', en: 'Walserhaus Hirschegg')
          second = article(de: 'Proberaum Walserhaus Hirschegg', en: 'Walserhaus Hirschegg')

          assert_empty rows_for(first, second)
        end

        test 'names agreeing in the current locale keep their score although English differs' do
          first = article(de: 'Parkplatz Adolari', en: 'Parkplatz Adolari')
          second = article(de: 'Parkplatz Adolari', en: 'parking space Adolari')

          assert_equal [100], rows_for(first, second).pluck(:score)
        end

        # the subject's name equals the other content's name in a different locale, which the
        # unrestricted join scored as a perfect match
        test 'a name equal to the other content in a different locale is not scored' do
          first = article(de: 'Alpha Haus', en: 'Beta Haus')
          second = article(de: 'Beta Haus', en: 'Gamma Haus')

          I18n.with_locale(:en) { assert_empty rows_for(first.reload, second) }
        end

        # the pair that made OnlyNameAndClassification's `.distinct` look necessary: agreeing in two
        # locales, the unrestricted join reached both translations of the same content and this
        # module - which builds its rows itself rather than through Base.candidate_rows - reported
        # it twice. The scope reaches one translation, so the row is single before anything dedupes.
        test 'a pair agreeing in two locales is reported once' do
          first = article(de: 'Auenhuette Hirschegg', en: 'Auenhuette Hirschegg')
          second = article(de: 'Auenhuette Hirschegg', en: 'Auenhuette Hirschegg')

          assert_equal 1, rows_for(first, second).size
        end

        test 'a content without a name in the current locale yields no candidates' do
          first = article(de: 'Ohne Englische Uebersetzung')
          article(de: 'Ohne Englische Uebersetzung')

          I18n.with_locale(:en) { assert_nil SUBJECT.duplicates(content: first.reload) }
        end

        test 'duplicates returns nil for a content without a name' do
          assert_nil SUBJECT.duplicates(content: struct_double(name: nil))
        end
      end
    end
  end
end
