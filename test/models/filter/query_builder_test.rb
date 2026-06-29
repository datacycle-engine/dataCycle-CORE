# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Filter
    # Coverage for the pure Arel-builder helpers and table accessors on QueryBuilder
    # (the base class of Filter::Search). All build Arel nodes without touching the DB.
    class QueryBuilderTest < DataCycleCore::TestCases::ActiveSupportTestCase
      def builder
        DataCycleCore::Filter::Search.new(locale: :de)
      end

      def node
        Arel.sql('geom')
      end

      test 'none returns an empty query' do
        assert_equal(0, builder.none.count)
      end

      test 'spatial arel builders construct named functions' do
        b = builder

        assert(b.send(:get_point, 1.0, 2.0))
        assert(b.send(:get_box, node, node))
        assert(b.send(:st_transform, node, 4326))
        assert(b.send(:st_contains, node, node))
        assert(b.send(:st_disjoint, node, node))
        assert(b.send(:contains, node, node))
        assert(b.send(:any, node))
      end

      test 'cast arel builders construct cast expressions' do
        b = builder

        assert(b.send(:cast_rrule, 'FREQ=DAILY'))
        assert(b.send(:cast_date, '2024-01-01'))
        assert(b.send(:cast, node, 'integer'))
      end

      test 'arel_table accessors return tables' do
        b = builder

        [:classification_content, :classification, :classification_tree, :classification_group, :classification_alias, :classification_polygon, :duplicate_candidate, :thing_duplicate, :thing_template].each do |accessor|
          assert_kind_of(Arel::Table, b.send(accessor))
        end
      end
    end
  end
end
