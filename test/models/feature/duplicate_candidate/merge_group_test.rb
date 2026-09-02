# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class DuplicateCandidateMergeGroupTest < DataCycleCore::TestCases::ActiveSupportTestCase
    include ActiveJob::TestHelper

    def subject
      DataCycleCore::Feature::DuplicateCandidate::MergePlan
    end

    test 'merges every duplicate of a group into the original' do
      places = Array.new(3) { |index| create_place("Bäckerei Mangold #{index}") }
      group = group_for(places)

      assert_equal places.map(&:id).sort, group.ids.sort
      assert_predicate group, :valid?
      assert_equal 2, group.duplicates.size

      assert_empty group.merge!

      assert_predicate DataCycleCore::Thing.where(id: group.original.id), :exists?
      group.duplicates.each { |duplicate| assert_nil DataCycleCore::Thing.find_by(id: duplicate.id), "duplicate #{duplicate.id} still exists" }
    end

    # two duplicates of one group linked from the same content and relation: the second merge
    # must not move its link onto the one the first merge already created
    test 'keeps a link shared by two duplicates of a group exactly once' do
      places = Array.new(3) { |index| create_place("Bäckerei Mangold #{index}") }
      group = group_for(places)
      event = DataCycleCore::TestPreparations.create_content(
        template_name: 'Event',
        data_hash: { name: 'Brotbacken', content_location: group.duplicates.map(&:id) }
      )

      assert_equal group.duplicates.map(&:id).sort, links_of(event).sort, 'the event has to link to both duplicates up front'

      assert_empty group.merge!

      assert_equal [group.original.id], links_of(event)
    end

    private

    def create_place(name)
      DataCycleCore::TestPreparations.create_content(template_name: 'Örtlichkeit', data_hash: { name: })
    end

    # the transitive group of all three places, from the pairs a file would list
    def group_for(places)
      pair_class = DataCycleCore::Feature::DuplicateCandidate::MergeSpreadsheet::Pair
      pairs = [
        pair_class.new('default', 2, places[0].id, places[1].id),
        pair_class.new('default', 3, places[1].id, places[2].id)
      ]

      plan = subject.call(pairs)

      assert_equal 1, plan.groups.size
      plan.groups.first
    end

    def links_of(content)
      DataCycleCore::ContentContent
        .where(content_a_id: content.id, relation_a: 'content_location')
        .pluck(:content_b_id)
    end
  end
end
