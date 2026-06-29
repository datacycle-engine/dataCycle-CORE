# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # Coverage for the OptimizedContentContents concern (included into Thing). The
  # recursive_*_query builders are pure SQL string generators - exercising them at
  # depth 0/1/2 covers every leaf/depth branch - and the instance helpers only build
  # (do not execute) a relation, so an unsaved Thing is enough.
  class OptimizedContentContentsCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
    test 'the instance recursive relations build for an unsaved thing without hitting the DB' do
      thing = DataCycleCore::Thing.new(template_name: DataCycleCore::ThingTemplate.first.template_name)

      assert_kind_of ActiveRecord::Relation, thing.recursive_content_links(depth: 0)
      assert_kind_of ActiveRecord::Relation, thing.recursive_content_content_a(depth: 0)
    end

    test 'the recursive query builders cover every depth branch' do
      [0, 1, 2].each do |depth|
        links = DataCycleCore::Thing.send(:recursive_content_links_query, depth:)
        content_a = DataCycleCore::Thing.send(:recursive_content_content_a_query, depth:)

        assert_includes links, 'WITH RECURSIVE'
        assert_includes content_a, 'WITH RECURSIVE'
      end
    end

    test 'the scoped class relation builder runs against an empty scope' do
      assert_nothing_raised do
        DataCycleCore::Thing.where(id: nil).recursive_content_links(depth: 0)
      end
    end
  end
end
