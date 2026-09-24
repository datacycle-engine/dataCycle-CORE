# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Filter
    module Common
      # exercises the advanced-attribute query builders mixed into Filter::Search;
      # each builder returns a reflected Filter, and .count validates the generated SQL runs.
      class AdvancedTest < DataCycleCore::TestCases::ActiveSupportTestCase
        UUID = '00000000-0000-0000-0000-000000000001'

        def search
          DataCycleCore::Filter::Search.new(locale: :de)
        end

        test 'advanced_string covers every comparison branch' do
          assert_operator(search.equals_advanced_string({ 'text' => 'a,b' }, 'attr').count, :>=, 0)
          assert_operator(search.not_equals_advanced_string({ 'text' => 'a' }, 'attr').count, :>=, 0)
          assert_operator(search.like_advanced_attributes({ 'text' => 'foo bar' }, 'string', 'attr').count, :>=, 0)
          assert_operator(search.not_like_advanced_attributes({ 'text' => 'foo' }, 'string', 'attr').count, :>=, 0)
          assert_operator(search.exists_advanced_attributes({ 'text' => 'x' }, 'string', 'attr').count, :>=, 0)
          assert_operator(search.not_exists_advanced_attributes({ 'text' => 'x' }, 'string', 'attr').count, :>=, 0)
          # unknown comparison falls through to the else/return-self branch
          assert_kind_of(DataCycleCore::Filter::Search, search.send(:advanced_string, { 'text' => 'x' }, 'attr', :unknown))
        end

        test 'advanced_boolean covers every comparison branch' do
          assert_operator(search.equals_advanced_boolean(true, 'attr').count, :>=, 0)
          assert_operator(search.not_equals_advanced_boolean(true, 'attr').count, :>=, 0)
          # ApiService dispatches a notIn filter through not_advanced_attributes with this hash value
          assert_operator(search.not_advanced_attributes({ bool: false }, 'boolean', 'attr').count, :>=, 0)
          assert_kind_of(DataCycleCore::Filter::Search, search.send(:advanced_boolean, true, 'attr', :unknown))
        end

        test 'advanced_concept_ids covers every comparison branch' do
          assert_operator(search.equals_advanced_concept_ids([UUID], 'attr').count, :>=, 0)
          assert_operator(search.not_equals_advanced_concept_ids([UUID], 'attr').count, :>=, 0)
          assert_operator(search.exists_advanced_concept_ids([UUID], 'attr').count, :>=, 0)
          assert_operator(search.not_exists_advanced_concept_ids([UUID], 'attr').count, :>=, 0)
          assert_kind_of(DataCycleCore::Filter::Search, search.send(:advanced_concept_ids, [UUID], 'attr', :unknown))
        end

        test 'advanced_date_range covers equal/not_equal with configured interval keys' do
          value = { 'from' => '2020-01-01', 'until' => '2020-12-31' }
          config = { 'attr' => { 'attribute_keys' => ['from_key', 'to_key'], 'query_operator' => 'overlaps' } }

          DataCycleCore::Feature::AdvancedFilter.stub(:available_advanced_attribute_filters, config) do
            assert_operator(search.equals_advanced_date_range(value, 'attr').count, :>=, 0)
            assert_operator(search.not_equals_advanced_date_range(value, 'attr').count, :>=, 0)
            assert_kind_of(DataCycleCore::Filter::Search, search.send(:advanced_date_range, value, 'attr', :unknown))
          end
        end

        test 'lower/greater_advanced_attributes dispatch to advanced_time' do
          assert_operator(search.lower_advanced_attributes('12:00', 'time', 'attr').count, :>=, 0)
          assert_operator(search.greater_advanced_attributes('12:00', 'time', 'attr').count, :>=, 0)
        end

        test 'equals_advanced_slug and the numeric/date else branches' do
          assert_operator(search.equals_advanced_slug({ equals: 'some-slug' }).count, :>=, 0)
          assert_kind_of(DataCycleCore::Filter::Search, search.send(:advanced_numeric, { 'equals' => '5' }, 'attr', :unknown))
          assert_kind_of(DataCycleCore::Filter::Search, search.send(:advanced_date, { 'from' => '2020-01-01' }, 'attr', :unknown))
        end

        # Canonical anchor for Filter::Common::Advanced#advanced_classification_contains, which
        # exists so index_searches_on_advanced_attributes can serve the filter. Reverting it to the
        # `jsonb_array_elements_text(...)::uuid[] && ARRAY[...]` form it replaced returns the same
        # rows, only via a Seq Scan, so only this test would notice.
        test 'equals_advanced_concept_ids builds an index-servable containment' do
          sql = search.equals_advanced_concept_ids([UUID], 'attr').query.to_sql

          assert_includes(sql, %(searches.advanced_attributes @> '{"attr":["#{UUID}"]}'::jsonb))
          assert_not_includes(sql, 'jsonb_array_elements_text')
        end

        test 'equals_advanced_concept_ids ORs one containment per requested id' do
          other = '00000000-0000-0000-0000-000000000002'
          sql = search.equals_advanced_concept_ids([UUID, other], 'attr').query.to_sql

          assert_includes(sql, %(searches.advanced_attributes @> '{"attr":["#{UUID}"]}'::jsonb OR ))
          assert_includes(sql, %(searches.advanced_attributes @> '{"attr":["#{other}"]}'::jsonb))
        end

        # `::uuid[]` normalized the case of the requested id and `@>` on JSON strings does not,
        # so without the downcase this filter answers nothing where it used to match.
        test 'equals_advanced_concept_ids matches an id requested in upper case' do
          mixed_case = '550E8400-E29B-41D4-A716-446655440000'
          sql = search.equals_advanced_concept_ids([mixed_case], 'attr').query.to_sql

          assert_includes(sql, %(searches.advanced_attributes @> '{"attr":["#{mixed_case.downcase}"]}'::jsonb))
        end

        # The containment and the array overlap it replaced have to agree for every shape
        # advanced_attributes can take, not just the matching one.
        test 'containment agrees with the array overlap it replaced, case by case' do
          other = '00000000-0000-0000-0000-000000000002'
          [
            %({"attr":["#{UUID}"]}),
            %({"attr":["#{other}"]}),
            %({"attr":["#{other}","#{UUID}"]}),
            %({"attr":[]}),
            %({"other":["#{UUID}"]}),
            '{}'
          ].each do |advanced_attributes|
            overlap, contains = DataCycleCore::Search.connection.select_rows(
              ActiveRecord::Base.send(:sanitize_sql, [<<~SQL.squish, advanced_attributes, UUID, advanced_attributes, UUID])
                SELECT (ARRAY(SELECT jsonb_array_elements_text(?::jsonb -> 'attr'))::uuid[] && ARRAY[?]::uuid[]),
                       (?::jsonb @> ('{"attr":["' || ? || '"]}')::jsonb)
              SQL
            ).first

            assert_equal(overlap, contains, "disagreed for advanced_attributes #{advanced_attributes}")
          end
        end

        test 'translated_name filters build tt_exists subqueries' do
          assert_operator(search.equals_advanced_translated_name({ 'text' => 'Foo' }).count, :>=, 0)
          assert_operator(search.not_equals_advanced_translated_name({ 'text' => 'Foo' }).count, :>=, 0)
          assert_operator(search.like_advanced_translated_name({ 'text' => 'Foo' }).count, :>=, 0)
          assert_operator(search.not_like_advanced_translated_name({ 'text' => 'Foo' }).count, :>=, 0)
          # exercises the value-nil branch of tt_exists_subquery
          assert_operator(search.exists_advanced_translated_name({ 'text' => 'x' }).count, :>=, 0)
          assert_operator(search.not_exists_advanced_translated_name({ 'text' => 'x' }).count, :>=, 0)
        end
      end
    end
  end
end
