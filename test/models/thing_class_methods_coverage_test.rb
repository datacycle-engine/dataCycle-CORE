# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # Coverage for DataCycleCore::Thing class-/instance-methods and the
  # DuplicateCandidate / PropertyDependency inner models.
  class ThingClassMethodsCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
    test 'Thing.duplicate_candidates builds a scoped relation' do
      relation = DataCycleCore::Thing.where(id: nil).duplicate_candidates

      assert_kind_of(ActiveRecord::Relation, relation)
      assert_empty(relation.to_a)
    end

    test 'Thing::History.translated_locales builds a distinct-locale query' do
      assert_kind_of(Array, DataCycleCore::Thing::History.where(id: nil).translated_locales)
    end

    test 'translation_updated_at returns nil without a matching translation' do
      assert_nil(DataCycleCore::Thing.new(template_name: 'POI').translation_updated_at)
    end

    test 'DuplicateCandidate and PropertyDependency are read-only' do
      assert_predicate(DataCycleCore::Thing::DuplicateCandidate.new, :readonly?)
      assert_predicate(DataCycleCore::Thing::PropertyDependency.new, :readonly?)
    end

    test 'DuplicateCandidate#duplicate_module resolves the module by identifier' do
      candidate = DataCycleCore::Thing::DuplicateCandidate.new(duplicate_method: 'data_metric_hamming')

      assert_equal(DataCycleCore::Utility::DuplicateCandidate::DataMetricHamming, candidate.duplicate_module)
    end
  end
end
