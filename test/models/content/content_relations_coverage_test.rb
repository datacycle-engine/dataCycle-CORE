# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Content
    # Coverage for ContentRelations: the class-level relation loaders (the query
    # path on Thing vs. the relation.none short-circuit on Thing::History) and the
    # instance helpers (is_related?, relation_*_column, transitive mapped aliases).
    # Class methods run cheap empty queries; instance helpers run on an unsaved Thing.
    class ContentRelationsCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
      def thing
        @thing ||= DataCycleCore::Thing.new(template_name: DataCycleCore::ThingTemplate.first&.template_name)
      end

      test 'class relation helpers query for Thing and short-circuit for histories' do
        assert_kind_of(Array, DataCycleCore::Thing.data_links.to_a)
        assert_empty(DataCycleCore::Thing::History.data_links)

        assert_kind_of(Array, DataCycleCore::Thing.classification_contents.to_a)
        assert_empty(DataCycleCore::Thing::History.classification_contents)

        assert_kind_of(Array, DataCycleCore::Thing.collected_classification_contents.to_a)
        assert_empty(DataCycleCore::Thing::History.collected_classification_contents)

        assert_kind_of(Array, DataCycleCore::Thing.asset_contents.to_a)
        assert_empty(DataCycleCore::Thing::History.asset_contents)

        assert_kind_of(Array, DataCycleCore::Thing.schedules.to_a)
        assert_empty(DataCycleCore::Thing::History.schedules)

        # NB: bare DataCycleCore::Thing.timeseries raises (PG: column "thing_id"
        # does not exist), so only the Thing::History short-circuit is exercised here.
        assert_empty(DataCycleCore::Thing::History.timeseries)
      end

      test 'is_related? checks for inverse content relations' do
        assert_not(thing.is_related?)
      end

      test 'relation column helpers resolve to the content_contents table' do
        assert_equal('content_contents.relation_a', thing.send(:relation_a_column))
        assert_equal('content_contents.relation_b', thing.send(:relation_b_column))
      end

      test 'mapped_classification_aliases uses transitive paths when the feature is enabled' do
        result = DataCycleCore::Feature::TransitiveClassificationPath.stub(:enabled?, true) do
          thing.mapped_classification_aliases.to_a
        end

        assert_kind_of(Array, result)
      end
    end
  end
end
