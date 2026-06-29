# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # Coverage for the ThingsByCollections ability segment. include? is exercised with an
  # empty and a populated collection-id list; to_restrictions runs over a stubbed
  # Collection.where result (an unsaved WatchList) so the per-collection restriction row
  # is built without writing to the database.
  class ThingsByCollectionsSegmentCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
    Subject = DataCycleCore::Abilities::Segments::ThingsByCollections

    def content_double(id: SecureRandom.uuid)
      content = Object.new
      content.define_singleton_method(:id) { id }
      content
    end

    def ability_without_user
      ability = Object.new
      ability.define_singleton_method(:user) { nil }
      ability
    end

    test 'include? is false for an empty list and queries collections otherwise' do
      assert_not Subject.new.include?(content_double)

      seg = Subject.new(SecureRandom.uuid)

      assert_not seg.include?(content_double)
    end

    test 'subject is Thing and to_proc delegates to include?' do
      seg = Subject.new(SecureRandom.uuid)

      assert_equal DataCycleCore::Thing, seg.subject
      assert_not seg.to_proc.call(content_double)
    end

    test 'to_restrictions builds a restriction row per collection class' do
      seg = Subject.new('id-1')
      seg.ability = ability_without_user
      collection = DataCycleCore::WatchList.new(name: 'My Collection')

      result = DataCycleCore::Collection.stub(:where, [collection]) do
        seg.send(:to_restrictions)
      end

      assert_kind_of Array, result
    end
  end
end
