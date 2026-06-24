# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ContentRelationsTest < DataCycleCore::TestCases::ActiveSupportTestCase
    before(:all) do
      I18n.with_locale(:de) do
        @organization = DataCycleCore::TestPreparations.create_content(
          template_name: 'Organization',
          data_hash: {
            name: 'Test Orgnaization 1'
          }
        )

        @person = DataCycleCore::TestPreparations.create_content(
          template_name: 'Person',
          data_hash: {
            given_name: 'Test',
            family_name: 'Person 1',
            member_of: [@organization.id]
          }
        )

        @bild = DataCycleCore::TestPreparations.create_content(
          template_name: 'Bild',
          data_hash: {
            name: 'Test Bild 1',
            author: [@person.id]
          }
        )

        @aggregate_offer = DataCycleCore::TestPreparations.create_content(
          template_name: 'Pauschalangebot',
          data_hash: {
            name: 'Test Pauschalangebot 1',
            offers: [{
              name: 'Test Angebot 1',
              offered_by: [@person.id],
              price_specification: [{ price: 9.99 }, { price: 19.99 }]
            }]
          }
        )

        @aggregate_offer2 = DataCycleCore::TestPreparations.create_content(
          template_name: 'Pauschalangebot',
          data_hash: {
            name: 'Test Pauschalangebot 2',
            image: [@bild.id]
          }
        )
      end
    end

    test 'method: related_contents' do
      assert_equal [@bild.id, @aggregate_offer.id].to_set, @person.related_contents.pluck(:id).to_set
      assert_equal [@aggregate_offer2.id], @bild.related_contents.pluck(:id)
      assert_equal 0, @aggregate_offer.related_contents.size
      assert_equal 0, @aggregate_offer2.related_contents.size
    end

    test 'method: linked_contents' do
      assert_equal 1, @person.linked_contents.size
      assert_empty @bild.linked_contents.pluck(:id).difference([@organization.id, @person.id])
      assert_equal 0, @aggregate_offer.linked_contents.size
      assert_empty @aggregate_offer2.linked_contents.pluck(:id).difference([@person.id, @bild.id, @organization.id])
    end

    test 'method: embedded_contents' do
      assert_equal 0, @bild.embedded_contents.size
      assert_equal 0, @person.embedded_contents.size
      assert_equal 3, @aggregate_offer.embedded_contents.size
      assert_equal 0, @aggregate_offer2.embedded_contents.size
    end

    test 'method: cached_related_contents?' do
      assert_not @aggregate_offer.cached_related_contents?
      assert_not @aggregate_offer2.cached_related_contents?
      assert_predicate @organization, :cached_related_contents?
      assert_predicate @person, :cached_related_contents?
      assert_predicate @bild, :cached_related_contents?
    end

    test 'method: cached_related_contents' do
      assert_equal 1, @aggregate_offer.with_cached_related_contents.size
      assert_equal 1, @aggregate_offer2.with_cached_related_contents.size
      assert_equal 6, @organization.with_cached_related_contents.size
      assert_equal 6, @person.with_cached_related_contents.size
      assert_equal 2, @bild.with_cached_related_contents.size
    end

    test 'method: depending_contents' do
      assert_equal 4, @organization.depending_contents.size
      assert_equal 4, @person.depending_contents.size
      assert_equal 1, @bild.depending_contents.size
      assert_equal 0, @aggregate_offer.depending_contents.size
      assert_equal 0, @aggregate_offer2.depending_contents.size
    end
  end
end
