# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Utility
    module DuplicateCandidate
      # Canonical coverage of the locale rule every name-comparing candidate module shares through
      # Base.same_locale_scope. The sibling tests for OnlyNameAndLocality, OnlyNameAndClassification
      # and NameSimilarity assert the same rule for their own module and point here for the reasoning.
      #
      # `content.name` resolves in the current locale and nothing else - Mobility runs without its
      # fallbacks plugin - while the joined translations carry every locale of every other content.
      # An unrestricted join therefore compared a German name against an English one, which is how
      # `dc:duplicates:create_duplicates[cleanup-feratel-event-locations]` came to offer "Walserhaus
      # Hirschegg" and "Proberaum Walserhaus Hirschegg" as a score-100 pair: Feratel delivers the
      # same English name for both, while the German names say plainly that they are two different
      # rooms.
      #
      # No merge ever consumed that row. The crossing is one-sided - recomputing "Walserhaus
      # Hirschegg" reaches the other room's English translation and writes the row, recomputing
      # "Proberaum Walserhaus Hirschegg" finds nothing and deletes it again - and the same nightly
      # task recomputes both ends before `dc:duplicates:merge_duplicates` reads them. Which of the
      # two WorkerPool threads commits last therefore decided whether the merge saw the row at all,
      # so an irreversible merge of two different rooms was one interleaving away.
      #
      # The rule is deliberately "the current locale decides", not "every locale must agree".
      # Counted on the Kitzbueheler Alpen production copy in September 2026, over the stored
      # only_title rows: 26263 pairs agree in German and differ in a machine-translated locale
      # ("Parkplatz Adolari" / "parking space Adolari"), against 546 that agree in some other locale
      # and differ in German. Demanding unanimity would discard roughly fifty true duplicates for
      # every false one.
      class OnlyTitleTest < DataCycleCore::TestCases::ActiveSupportTestCase
        SUBJECT = DataCycleCore::Utility::DuplicateCandidate::OnlyTitle
        TEMPLATE = 'Artikel'

        def article(de:, en: nil)
          content = DataCycleCore::Thing.new(template_name: TEMPLATE)
          content.save!(touch: false)
          content.set_data_hash(data_hash: { 'name' => de }, prevent_history: true)
          I18n.with_locale(:en) { content.set_data_hash(data_hash: { 'name' => en }, partial_update: true, prevent_history: true) } if en

          content.reload

          # most cases below assert an absence, which a helper that had quietly stopped writing one
          # of the two names would satisfy for the wrong reason
          assert_equal de, content.name
          assert_equal en, I18n.with_locale(:en) { content.name } if en

          content
        end

        def poi(de:)
          content = DataCycleCore::Thing.new(template_name: 'POI')
          content.save!(touch: false)
          content.set_data_hash(data_hash: { 'name' => de }, prevent_history: true)
          content.reload

          assert_equal de, content.name

          content
        end

        def candidate_ids(content)
          Array.wrap(SUBJECT.duplicates(content:)).pluck(:thing_duplicate_id)
        end

        test 'the same name in the current locale is a candidate scored 83' do
          first = article(de: 'Titel Gleich')
          second = article(de: 'Titel Gleich')

          assert_equal [second.id], candidate_ids(first)
          assert_equal [83], Array.wrap(SUBJECT.duplicates(content: first)).pluck(:score)
        end

        test 'names differing in the current locale are not a candidate although English agrees' do
          first = article(de: 'Walserhaus Hirschegg', en: 'Walserhaus Hirschegg')
          second = article(de: 'Proberaum Walserhaus Hirschegg', en: 'Walserhaus Hirschegg')

          assert_not_includes candidate_ids(first), second.id
          assert_not_includes candidate_ids(second), first.id
        end

        test 'names agreeing in the current locale stay a candidate although English differs' do
          first = article(de: 'Parkplatz Adolari', en: 'Parkplatz Adolari')
          second = article(de: 'Parkplatz Adolari', en: 'parking space Adolari')

          assert_includes candidate_ids(first), second.id
          assert_includes candidate_ids(second), first.id
        end

        # the mirror image of the case above: here it is the subject's name that equals the other
        # content's name in a different locale. Both directions of the crossing have to be closed.
        test 'a name equal to the other content in a different locale is not a candidate' do
          first = article(de: 'Alpha Haus', en: 'Beta Haus')
          second = article(de: 'Beta Haus', en: 'Gamma Haus')

          I18n.with_locale(:en) { assert_not_includes candidate_ids(first.reload), second.id }
        end

        # the English name has to equal the other content's German one, or the old unrestricted join
        # would have found nothing here either and the case would say nothing about the fix
        test 'a candidate without a translation in the current locale is not compared' do
          first = article(de: 'Nur Deutsch', en: 'Nur Deutsch')
          second = article(de: 'Nur Deutsch')

          assert_includes candidate_ids(first), second.id
          I18n.with_locale(:en) { assert_not_includes candidate_ids(first.reload), second.id }
        end

        # the positive counterpart of the cases above: the rule follows the current locale rather
        # than always reading the default one, and the English translations really are written
        test 'names agreeing in English are a candidate for an English writer' do
          first = article(de: 'Alpha Haus', en: 'Kapelle Oberlech')
          second = article(de: 'Beta Haus', en: 'Kapelle Oberlech')

          assert_not_includes candidate_ids(first), second.id
          I18n.with_locale(:en) { assert_includes candidate_ids(first.reload), second.id }
        end

        # same_locale_scope carries the template restriction for all five rules, so one case covers
        # them: an identical name across two templates is not a pair
        test 'a content of another template carrying the same name is not a candidate' do
          first = article(de: 'Gleicher Name Andere Vorlage')
          same_template = article(de: 'Gleicher Name Andere Vorlage')
          other = poi(de: 'Gleicher Name Andere Vorlage')

          assert_includes candidate_ids(first), same_template.id
          assert_not_includes candidate_ids(first), other.id
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
