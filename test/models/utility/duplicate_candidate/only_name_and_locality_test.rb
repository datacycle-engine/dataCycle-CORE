# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Utility
    module DuplicateCandidate
      # The name half of this rule is locale bound, the address half is not: address is stored with
      # storage_location "value" and therefore lives untranslated in things.metadata. See
      # OnlyTitleTest for why the name comparison is pinned to one locale.
      class OnlyNameAndLocalityTest < DataCycleCore::TestCases::ActiveSupportTestCase
        SUBJECT = DataCycleCore::Utility::DuplicateCandidate::OnlyNameAndLocality
        TEMPLATE = 'POI'

        def poi(de:, locality:, en: nil)
          content = DataCycleCore::Thing.new(template_name: TEMPLATE)
          content.save!(touch: false)
          content.set_data_hash(data_hash: { 'name' => de, 'address' => { 'address_locality' => locality } }, prevent_history: true)
          I18n.with_locale(:en) { content.set_data_hash(data_hash: { 'name' => en }, partial_update: true, prevent_history: true) } if en

          content.reload
        end

        def candidate_ids(content)
          Array.wrap(SUBJECT.duplicates(content:)).pluck(:thing_duplicate_id)
        end

        test 'the same name and locality is a candidate scored 100' do
          first = poi(de: 'Auenhuette', locality: 'Hirschegg')
          second = poi(de: 'Auenhuette', locality: 'Hirschegg')

          assert_equal [{ thing_duplicate_id: second.id, method: 'only_name_and_locality', score: 100 }],
                       Array.wrap(SUBJECT.duplicates(content: first))
        end

        test 'the same name in a different locality is not a candidate' do
          first = poi(de: 'Pfarrkirche', locality: 'Hirschegg')
          second = poi(de: 'Pfarrkirche', locality: 'Oberlech')

          assert_not_includes candidate_ids(first), second.id
        end

        test 'names differing in the current locale are not a candidate although English agrees' do
          first = poi(de: 'Walserhaus Hirschegg', locality: 'Hirschegg', en: 'Walserhaus Hirschegg')
          second = poi(de: 'Proberaum Walserhaus Hirschegg', locality: 'Hirschegg', en: 'Walserhaus Hirschegg')

          assert_not_includes candidate_ids(first), second.id
          assert_not_includes candidate_ids(second), first.id
        end

        test 'names agreeing in the current locale stay a candidate although English differs' do
          first = poi(de: 'Parkplatz Adolari', locality: 'Hirschegg', en: 'Parkplatz Adolari')
          second = poi(de: 'Parkplatz Adolari', locality: 'Hirschegg', en: 'parking space Adolari')

          assert_includes candidate_ids(first), second.id
          assert_includes candidate_ids(second), first.id
        end

        test 'a name equal to the other content in a different locale is not a candidate' do
          first = poi(de: 'Alpha Haus', locality: 'Hirschegg', en: 'Beta Haus')
          second = poi(de: 'Beta Haus', locality: 'Hirschegg', en: 'Gamma Haus')

          I18n.with_locale(:en) { assert_not_includes candidate_ids(first.reload), second.id }
        end

        test 'a content without a name in the current locale yields no candidates' do
          first = poi(de: 'Ohne Englische Uebersetzung', locality: 'Hirschegg')
          poi(de: 'Ohne Englische Uebersetzung', locality: 'Hirschegg')

          I18n.with_locale(:en) { assert_nil SUBJECT.duplicates(content: first.reload) }
        end

        test 'duplicates returns nil for a content without a name' do
          assert_nil SUBJECT.duplicates(content: struct_double(name: nil))
        end

        test 'duplicates returns nil for a content without a locality' do
          content = DataCycleCore::Thing.new(template_name: TEMPLATE)
          content.save!(touch: false)
          content.set_data_hash(data_hash: { 'name' => 'Ohne Adresse' }, prevent_history: true)

          assert_nil SUBJECT.duplicates(content: content.reload)
        end
      end
    end
  end
end
