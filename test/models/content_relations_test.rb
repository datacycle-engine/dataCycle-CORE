# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ContentRelationsTest < ActiveSupport::TestCase
    def setup
      I18n.with_locale(:de) do
        @person = DataCycleCore::TestPreparations.create_content(template_name: 'Person', data_hash: { given_name: 'Test', family_name: 'Person 1' })
        @bild = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Test Bild 1', author: [@person.id] })
        @aggregate_offer = DataCycleCore::TestPreparations.create_content(template_name: 'Pauschalangebot', data_hash: { name: 'Test Pauschalangebot 1', offers: [{ name: 'Test Angebot 1', offered_by: [@person.id], price_specification: [{ price: 9.99 }, { price: 19.99 }] }] })
        @aggregate_offer2 = DataCycleCore::TestPreparations.create_content(template_name: 'Pauschalangebot', data_hash: { name: 'Test Pauschalangebot 2', image: [@bild.id] })
      end
    end

    test 'method: related_contents' do
      assert_equal [@bild.id, @aggregate_offer.id].to_set, @person.related_contents.pluck(:id).to_set
      assert_equal [@aggregate_offer2.id], @bild.related_contents.pluck(:id)
      assert_equal 0, @aggregate_offer.related_contents.size
      assert_equal 0, @aggregate_offer2.related_contents.size
    end

    test 'method: linked_contents' do
      assert_equal 0, @person.linked_contents.size
      assert_equal [@person.id], @bild.linked_contents.pluck(:id)
      assert_equal 0, @aggregate_offer.linked_contents.size
      assert_equal [@person.id, @bild.id].to_set, @aggregate_offer2.linked_contents.pluck(:id).to_set
    end

    test 'method: embedded_contents' do
      assert_equal 0, @bild.embedded_contents.size
      assert_equal 0, @person.embedded_contents.size
      assert_equal 3, @aggregate_offer.embedded_contents.size
      assert_equal 0, @aggregate_offer2.embedded_contents.size
    end
  end
end
